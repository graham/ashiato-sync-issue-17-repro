extends Node
## Host-authoritative generated ATC. Kokoro exists only on the host. Its captured
## PCM is encoded once, carried by LongTransfer, and every machine (host included)
## plays the same decoded bytes.

signal changed(status: String)
signal clip_played(id: int, samples: int, from_peer: int)

const STALE_FRAMES: float = 3.0 * 120.0
const MOST_TEXT: int = 160
const MOST_WORDS: int = 18

var status: String = ""
var next_id: int = 1
var sent_to: int = 0
var last_clip: PackedByteArray = PackedByteArray()
var refused: int = 0
## WHO THE LINE BEING GENERATED IS FOR: a `TeamBoard` team, or `NOBODY` for everyone. Kept here between the press and
## the render finishing, because Kokoro answers on its own thread some hundreds of milliseconds later and the audience
## was chosen when the button was pressed.
##
## NOT A PARAMETER ON `rendered`: that signal is `Headphones`', and a text-to-speech voice has no business knowing what
## a team is.
var _for_team: int = TeamBoard.NOBODY

func _ready() -> void:
	Headphones.rendered.connect(_on_rendered)
	Headphones.render_failed.connect(func(why: String): _say(why))
	Net.long_message_arrived.connect(_on_long_message)
	Net.set_long_validator(&"clip", func(bytes: PackedByteArray): return RadioClip.problem(bytes).is_empty())

## SPEAK A LINE, to everybody or to one team. `to_team` is a `TeamBoard` team, or `NOBODY` for the whole session.
##
## The user asked for the two audiences on live voice and team-lead asked for the generated line to obey them too: a
## player would not expect a spoken order to reach a team they are not on just because a machine said it.
func speak(text: String, to_team: int = TeamBoard.NOBODY) -> String:
	var why := why_not(text)
	if not why.is_empty(): _say(why); return why
	if to_team != TeamBoard.NOBODY and not TeamBoard.holds(to_team):
		why = "There is no team %d to speak to." % to_team
		_say(why); return why
	_for_team = to_team
	why = Headphones.render(text.strip_edges())
	if not why.is_empty(): _for_team = TeamBoard.NOBODY; _say(why); return why
	_say("Generating radio line%s..." % ("" if to_team == TeamBoard.NOBODY else " for %s" % TeamBoard.name_of(to_team)))
	return ""

func why_not(text: String) -> String:
	if not Net.is_host: return "Only the host speaks on the radio."
	var clean := text.strip_edges()
	if clean.is_empty(): return "Type or choose a radio line first."
	if clean.length() > MOST_TEXT: return "A radio line may be at most %d characters." % MOST_TEXT
	if clean.split(" ", false).size() > MOST_WORDS: return "A radio line may be at most %d words." % MOST_WORDS
	for i in range(clean.length()):
		var code := clean.unicode_at(i)
		if code < 32 or code == 127: return "A radio line contains a control character."
	return ""

func _on_rendered(samples: PackedFloat32Array, sample_rate: int, text: String) -> void:
	var team: int = _for_team
	_for_team = TeamBoard.NOBODY
	publish_pcm(samples, sample_rate, text, team)

func publish_pcm(samples: PackedFloat32Array, sample_rate: int, text: String = "",
		to_team: int = TeamBoard.NOBODY) -> String:
	if not Net.is_host: return "Only the host sends radio clips."
	var clip := RadioClip.encode(samples, sample_rate, next_id, int(_server_frame()))
	if clip.is_empty(): _say("The generated line was empty or longer than seven seconds."); return status
	next_id += 1; last_clip = clip
	# Host playback deliberately begins here, after encode/decode, never on the
	# Kokoro capture channel. This is the same path every client takes.
	# THE HOST IS A LISTENER LIKE ANY OTHER and is subject to the same filter: a line sent to BLUE is not heard by a host
	# on RED, however much it was the host that said it. `TeamBoard.share_a_team` is the one place that answers this, the
	# same function the live voice routing asks.
	sent_to = 0
	if _may_hear(to_team, Sim.local_client_id()):
		sent_to = 1
		_play(clip, Net.my_peer_id())
	if Net.is_networked():
		for peer in multiplayer.get_peers():
			if not Net.admits(peer): continue
			var listener: int = Sim.server_client_of_peer(int(peer))
			if listener <= 0: listener = Sim.client_of_peer(int(peer))
			if not _may_hear(to_team, listener): continue
			var why := Net.send_long(peer, &"clip", clip, int(LongTransfer.KINDS[&"clip"]["life"]))
			if why.is_empty(): sent_to += 1
	_say("Sent to %d player%s%s" % [sent_to, "" if sent_to == 1 else "s",
		"." if text.is_empty() else ": %s" % text.left(64)])
	return ""

## MAY THAT PLAYER HEAR A LINE SENT TO `to_team`. Everyone hears a line for nobody's team; otherwise it is the same
## question the live voice asks, answered by the same function.
static func _may_hear(to_team: int, listener: int) -> bool:
	if to_team == TeamBoard.NOBODY:
		return true
	return listener > 0 and TeamBoard.share_a_team(to_team, Net.team_of(listener))


func _on_long_message(from_peer: int, kind: StringName, bytes: PackedByteArray) -> void:
	if kind != &"clip": return
	if from_peer != 1 or Net.is_host:
		refused += 1; push_warning("[radio] radio clip from a non-host was refused"); return
	var decoded := RadioClip.decode(bytes)
	if decoded.has("why"): refused += 1; return
	# LongTransfer already expires this document after three wall seconds. The
	# frame check adds simulation staleness only when the synchronized clock
	# exists; standalone peer harnesses deliberately have no CockpitWorld.
	if Sim.client != null and _server_frame() - float(decoded["spoken_frame"]) > STALE_FRAMES:
		refused += 1; print("[radio] stale clip %d dropped" % decoded["id"]); return
	_play(bytes, from_peer)

## PLAY A CLIP, AND ANNOUNCE IT WHERE THE LIVE VOICE IS ANNOUNCED.
##
## The audio still plays through `Headphones` on the Radio bus -- a generated line and a person's voice are on separate
## buses, which is half of what the user asked for -- but `Intercom.announce` is told, so a machine has ONE place that
## says "here is audio, from this player, of this kind" whichever carrier brought it. Announce and not play: two doors
## into one set of speakers would play every line twice.
func _play(bytes: PackedByteArray, from_peer: int) -> void:
	var decoded := RadioClip.decode(bytes)
	if decoded.has("why") or not Headphones.play_clip(bytes): return
	var samples: int = (decoded["samples"] as PackedInt32Array).size()
	clip_played.emit(int(decoded["id"]), samples, from_peer)
	var room: Node = Intercom.the_one_in_the_room
	if room != null and room.has_method("announce"):
		room.call("announce", 1, VoiceFrame.Kind.GENERATED, samples)

func phrases() -> Array[Dictionary]:
	var available := RadioPhrases.usable(); var slots := RadioPhrases.station_slots()
	var out: Array[Dictionary] = []
	for id in available:
		var entry: Dictionary = available[id]
		if StringName(entry["speaker"]) != &"tower": continue
		var text := RadioPhrases.fill(String(entry["text"]), slots)
		if not text.is_empty() and not text.contains("{"):
			out.append({"id": id, "text": text})
	out.sort_custom(func(a: Dictionary, b: Dictionary): return String(a.id) < String(b.id))
	return out

func _say(words: String) -> void:
	status = words; changed.emit(status); print("[radio] %s" % words)

static func _server_frame() -> float:
	if Sim.client != null:
		return float(Sim.client.timing().get("estimated_server_frame", Engine.get_physics_frames()))
	return float(Engine.get_physics_frames())
