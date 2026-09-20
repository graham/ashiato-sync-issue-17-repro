extends Node
## The persistent level curtain's contract without loading a large world. Network provenance/validation is held by
## level_hello and the real ENet notices suite; this holds scheduling, opacity, stale revisions and session reset.

var _failed: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[transition_curtain] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failed.append(label)


func _ready() -> void:
	var island: LevelChart = ChartDrawer.chart("island")
	var epoch: int = Net.session_epoch
	var cue := {"kind": "level", "target": "island", "hash": island.content_hash, "revision": 4, "epoch": epoch,
		"due": Time.get_ticks_msec() + Transition.FADE_MSEC + Transition.COVER_EARLY_MSEC + 40}
	_check("a_valid_local_epoch_cue_is_accepted", Transition.accept_level_cue(cue), "%s" % [cue])
	_check("a_duplicate_revision_in_one_session_is_stale", not Transition.accept_level_cue(cue),
		"revision %d" % Transition.revision())
	var bad: Dictionary = cue.duplicate()
	bad["revision"] = 5
	bad["hash"] = "somebody else's level"
	_check("a_cue_for_different_content_is_refused", not Transition.accept_level_cue(bad), "%s" % [bad])
	Net.hear_hello(42, JSON.stringify({"say": "notice", "kind": "level", "level": "island",
		"hash": island.content_hash, "in": 400, "n": 6}).to_utf8_buffer())
	_check("a_level_cue_from_a_non_host_peer_is_ignored", Transition.revision() == 4,
		"revision %d" % Transition.revision())
	var began: int = Time.get_ticks_msec()
	while Transition.opacity() < 0.999 and Time.get_ticks_msec() - began < 3000:
		await get_tree().process_frame
	_check("the_curtain_becomes_fully_black_before_load", Transition.opacity() >= 0.999,
		"opacity %.3f" % Transition.opacity())
	Net.level_loaded_here.emit("island")
	began = Time.get_ticks_msec()
	while Transition.opacity() > 0.001 and Time.get_ticks_msec() - began < 3000:
		await get_tree().process_frame
	_check("the_curtain_fades_back_after_local_level_ready", Transition.opacity() <= 0.001,
		"opacity %.3f" % Transition.opacity())

	# `_start_afresh` is the boundary every new solo, host and join path crosses. A persistent autoload must forget the old
	# session's high revision there or revision zero in a later session is rejected forever.
	Net.play_solo()
	var second := {"kind": "level", "target": "island", "hash": island.content_hash, "revision": 0,
		"epoch": Net.session_epoch, "due": Time.get_ticks_msec() + 10000}
	_check("a_new_session_accepts_revision_zero", Transition.accept_level_cue(second),
		"epoch %d revision %d" % [Net.session_epoch, Transition.revision()])
	var target: String = "lobby" if Net.level != "lobby" else "island"
	_check("a_level_change_can_be_called", Net.call_the_level(target) == "", "target %s" % target)
	var level_notice: Dictionary = Net.notice.duplicate()
	var version: int = int(Net.get("_notice_version"))
	var another_time: int = (Daylight.nearest_preset(Net.clock_now()) + 1) % DaylightTuning.When.size()
	Net.choose_time(another_time)
	_check("a_sky_change_does_not_replace_an_active_level_transition_cue",
		Net.notice == level_notice and int(Net.get("_notice_version")) == version and Net.notice.get("kind") == "level",
		"notice %s, version %d -> %d" % [Net.notice, version, int(Net.get("_notice_version"))])
	Net.leave("transition curtain suite")
	print("[transition_curtain] RESULT=%s %s" % ["PASS" if _failed.is_empty() else "FAIL", ", ".join(_failed)])
	get_tree().quit(0 if _failed.is_empty() else 1)
