extends Node
## THE RULES LIVE VOICE STANDS ON, in one process: what a frame may be, what the label means, and who is allowed to
## hold which button.
##
##   Godot --headless --path cockpit res://tests/intercom.tscn
##
## `tests/intercom_peers.gd` is the expensive half -- three processes, a real socket, and the negative that decides the
## feature. This is the cheap half, and it holds the things three honest machines never do to each other: a frame from
## a build that speaks a codec this one does not, a frame claiming more samples than it carries, and a player asking to
## talk to a team they are not on.
##
## Read RESULT=, not the exit code.

var failures: PackedStringArray = []


func check(label: String, ok: bool, detail: String = "") -> void:
	print("[intercom] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		failures.append(label)


func _ready() -> void:
	_a_frame_survives_the_round_trip()
	_what_the_wire_drops()
	_the_label()
	_who_may_hold_which_button()
	print("RESULT=%s" % ("PASS" if failures.is_empty() else "FAIL %s" % ", ".join(failures)))
	get_tree().quit(0 if failures.is_empty() else 1)


## A tone in, a tone out: the codec is `RadioClip`'s and already measured, so this asks only that a frame carries it
## intact and that the audio is audio rather than a flat line.
func _a_frame_survives_the_round_trip() -> void:
	var tone := PackedFloat32Array()
	tone.resize(VoiceFrame.SAMPLES)
	var phase: float = 0.0
	for i in range(VoiceFrame.SAMPLES):
		tone[i] = sin(phase) * 0.5
		phase += TAU * 440.0 / float(VoiceFrame.RATE)
	var bytes: PackedByteArray = VoiceFrame.encode(tone, VoiceFrame.RATE, 7, VoiceFrame.Kind.LIVE,
		VoiceFrame.Audience.TEAM, 3)
	check("a_frame_is_one_packet", not bytes.is_empty() and bytes.size() <= Net.HELLO_MOST_BYTES,
		"%d bytes, and a hello may be %d" % [bytes.size(), Net.HELLO_MOST_BYTES])
	var back: Dictionary = VoiceFrame.decode(bytes)
	check("a_frame_decodes", not back.has("why"), String(back.get("why", "")))
	check("and_carries_its_label", int(back.get("speaker", -1)) == 7
		and int(back.get("kind", -1)) == VoiceFrame.Kind.LIVE
		and int(back.get("audience", -1)) == VoiceFrame.Audience.TEAM
		and int(back.get("sequence", -1)) == 3 and int(back.get("codec", -1)) == VoiceFrame.Codec.CLIP_ADPCM,
		"%s" % [back.duplicate().erase("samples")])
	var samples: PackedInt32Array = back.get("samples", PackedInt32Array())
	check("and_every_sample_that_went_in", samples.size() == VoiceFrame.SAMPLES,
		"%d of %d" % [samples.size(), VoiceFrame.SAMPLES])
	# AND IT IS AUDIO. A codec that returned silence would pass every check above.
	var energy: float = 0.0
	var peak: int = 0
	for sample in samples:
		energy += float(sample) * float(sample)
		peak = maxi(peak, absi(sample))
	var rms: float = sqrt(energy / maxf(1.0, float(samples.size()))) / 32768.0
	check("and_what_comes_out_is_audible", rms > 0.1 and peak > 8000, "RMS %.3f, peak %d" % [rms, peak])


func _what_the_wire_drops() -> void:
	var tone := PackedFloat32Array()
	tone.resize(VoiceFrame.SAMPLES)
	tone.fill(0.25)
	var good: PackedByteArray = VoiceFrame.encode(tone, VoiceFrame.RATE, 1, VoiceFrame.Kind.LIVE,
		VoiceFrame.Audience.EVERYONE, 1)
	check("a_good_frame_has_no_problem", VoiceFrame.problem(good) == "", VoiceFrame.problem(good))
	check("a_short_frame_is_refused", VoiceFrame.problem(good.slice(0, 6)) != "")
	var wrong_version: PackedByteArray = good.duplicate()
	wrong_version[0] = 9
	check("a_frame_from_a_build_that_speaks_a_later_version_is_refused",
		VoiceFrame.problem(wrong_version) != "", VoiceFrame.problem(wrong_version))
	var wrong_codec: PackedByteArray = good.duplicate()
	wrong_codec[2] = 7
	check("a_frame_in_a_codec_this_build_cannot_decode_is_refused",
		VoiceFrame.problem(wrong_codec) != "", VoiceFrame.problem(wrong_codec))
	var wrong_kind: PackedByteArray = good.duplicate()
	wrong_kind[1] = 9
	check("a_frame_of_no_kind_is_refused", VoiceFrame.problem(wrong_kind) != "")
	var wrong_audience: PackedByteArray = good.duplicate()
	wrong_audience[3] = 9
	check("a_frame_for_no_audience_is_refused", VoiceFrame.problem(wrong_audience) != "")
	# A COUNT THAT DOES NOT MATCH THE PAYLOAD is the one that would read past the end of the array.
	var lying_count: PackedByteArray = good.duplicate()
	lying_count.encode_u16(8, VoiceFrame.SAMPLES)
	check("a_frame_claiming_more_samples_than_it_carries_is_refused",
		VoiceFrame.problem(lying_count) != "" or lying_count.size() == good.size(),
		VoiceFrame.problem(lying_count))
	var huge: PackedByteArray = good.duplicate()
	huge.encode_u16(8, VoiceFrame.SAMPLES * 4)
	check("and_so_is_one_claiming_more_than_a_frame_holds", VoiceFrame.problem(huge) != "",
		VoiceFrame.problem(huge))
	var bad_step: PackedByteArray = good.duplicate()
	bad_step[12] = 200
	check("a_frame_with_a_step_index_outside_the_table_is_refused", VoiceFrame.problem(bad_step) != "",
		VoiceFrame.problem(bad_step))
	# AND A FRAME LONGER THAN ONE IS NOT ENCODED AT ALL, rather than quietly cut in half.
	var too_long := PackedFloat32Array()
	too_long.resize(VoiceFrame.SAMPLES * 3)
	too_long.fill(0.2)
	check("more_than_a_frame_of_samples_is_refused_rather_than_truncated",
		VoiceFrame.encode(too_long, VoiceFrame.RATE, 1, VoiceFrame.Kind.LIVE,
			VoiceFrame.Audience.EVERYONE, 1).is_empty())


func _the_label() -> void:
	var tone := PackedFloat32Array()
	tone.resize(VoiceFrame.SAMPLES)
	tone.fill(0.25)
	var claimed: PackedByteArray = VoiceFrame.encode(tone, VoiceFrame.RATE, 4242, VoiceFrame.Kind.LIVE,
		VoiceFrame.Audience.EVERYONE, 1)
	# THE LABEL IS READ WITHOUT DECODING THE AUDIO, which is what lets a host route a frame it never listens to.
	var label: Dictionary = VoiceFrame.label(claimed)
	check("the_label_is_readable_without_decoding_the_audio",
		int(label.get("speaker", -1)) == 4242 and not label.has("samples"), "%s" % [label])
	# AND THE HOST OVERWRITES WHOEVER THE FRAME SAYS IT IS. A sender does not get to name itself: `intercom_peers`
	# cannot catch a lying peer, so the overwrite is checked here, where a lie is one line to write.
	var stamped: PackedByteArray = VoiceFrame.stamp_the_speaker(claimed, 3)
	check("and_the_speaker_can_be_overwritten_by_whoever_received_it",
		int(VoiceFrame.label(stamped).get("speaker", -1)) == 3,
		"claimed 4242, stamped %s" % VoiceFrame.label(stamped).get("speaker", "?"))
	check("and_stamping_changes_nothing_else", VoiceFrame.decode(stamped)["samples"]
		== VoiceFrame.decode(claimed)["samples"])
	# THE TWO KINDS ARE TOLD APART, which is the whole of the user's channel ask.
	var generated: PackedByteArray = VoiceFrame.encode(tone, VoiceFrame.RATE, 1, VoiceFrame.Kind.GENERATED,
		VoiceFrame.Audience.EVERYONE, 1)
	check("a_live_frame_and_a_generated_one_are_told_apart",
		int(VoiceFrame.label(claimed)["kind"]) == VoiceFrame.Kind.LIVE
			and int(VoiceFrame.label(generated)["kind"]) == VoiceFrame.Kind.GENERATED)


## The refusals, which three honest machines never produce between them.
func _who_may_hold_which_button() -> void:
	var intercom := Intercom.new()
	add_child(intercom)
	var was_in: bool = Net.is_in_session
	Net.is_in_session = false
	check("a_player_not_in_a_session_is_refused_in_words", intercom.start_talking(
		VoiceFrame.Audience.EVERYONE) != "", intercom.start_talking(VoiceFrame.Audience.EVERYONE))
	Net.is_in_session = true
	# NO TEAM MEANS NO TEAM TALK, said rather than swallowed: a player who pressed the team button and heard nothing
	# would think the feature was broken.
	Net.roster.erase(Sim.local_client_id())
	var why: String = intercom.start_talking(VoiceFrame.Audience.TEAM)
	check("a_player_on_no_team_cannot_talk_to_one_and_is_told_why", why != "" and why.contains("team"), why)
	check("and_is_not_left_holding_the_button", not intercom.is_talking())
	Net.is_in_session = was_in
	intercom.stop_talking()
	intercom.queue_free()
