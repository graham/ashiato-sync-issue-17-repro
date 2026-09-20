class_name Intercom
extends Node
## LIVE PLAYER VOICE: the button you hold, the frames it makes, and the audio that arrives from everybody else.
##
## NOT `Headphones` AND NOT `Radio`, and the names matter. `Headphones` is the Kokoro text-to-speech voice and `Radio`
## is the generated ATC line it speaks; both are about audio the HOST invents. This is people talking into microphones.
## Conflating them would make "the voice is on" two different questions.
##
## ---------------------------------------------------------------------------------------------------
## TWO CARRIERS UNDERNEATH, ONE LABELLED ARRIVAL POINT ON TOP
## ---------------------------------------------------------------------------------------------------
##
## The user asked whether there can be more than one channel of audio from the server, so that human speech and
## generated speech can be played apart or mixed by hand. There can, and the way to give it to them is NOT one
## transport carrying both.
##
## A generated line is a bounded document that must arrive whole: `Radio` already sends it as a `clip` through
## `LongTransfer`, which retries a missing chunk, and that is measured at 25.98 dB speech-band SNR with exact
## completion through 10% loss. Live voice is droppable frames that must never wait for a retry -- a frame that arrives
## late is worth less than nothing. **Forcing one carrier on both would make the generated line stutter or the live
## voice block.**
##
## So there are two carriers, and from the client's side exactly ONE place that says "here is audio, from this player,
## of this kind", whichever carrier brought it: `heard`. "Channels I can mix myself" needs one labelled arrival point,
## not one transport. A receiver can put `LIVE` and `GENERATED` on separate buses, mix them, or mute one, and none of
## that touches the wire.
##
## ---------------------------------------------------------------------------------------------------
## THE LAMP IS THE HOST'S ANSWER, NEVER THIS MACHINE'S GUESS
## ---------------------------------------------------------------------------------------------------
##
## `Net.is_talking` is what a lamp reads. This object never sets one from "I am receiving frames from that player",
## because a listener on another team receives NONE of a team-talker's audio and must still see them lit -- the user
## asked for an indicator that is always visible. The audio and the lamp carry the same `speaker`, from the same host,
## so they cannot disagree.

## AUDIO HAS ARRIVED AND BEEN PLAYED. `speaker` is the sync client id, `kind` is a `VoiceFrame.Kind`. The one labelled
## arrival point: a level that wants the two kinds on different buses listens here and nowhere else.
signal heard(speaker: int, kind: int, samples: int)
## The push-to-talk state changed on THIS machine: who this player is talking to, or `Audience.EVERYONE` when silent
## and `_talking` false. For the lobby's own hint line.
signal my_button_changed(holding: bool, audience: int)

## The bus arriving voice plays on. Its own, so a level can turn people down without touching the radio.
const BUS: StringName = &"Intercom"

## THE ONE IN THE ROOM, if a room has made one. `Radio` announces a generated line through it so that both kinds of
## audio arrive at one labelled point; a machine with no intercom (every flight-sim scene today) simply has none, and
## `Radio` checks. A static rather than an autoload because live voice belongs to the rooms that want it, not to every
## scene in the game.
##
## TYPED `Node` AND NOT `Intercom`, which it obviously is. GDScript refuses `the_one_in_the_room = self` while this
## class is still being compiled -- "Value of type gdscript://... cannot be assigned to a variable of type Intercom" --
## because the class it would be checking against is the one it is in the middle of building. `Node` is the honest
## workaround; the one caller asks `has_method` rather than pretending to know more than the parser does.
static var the_one_in_the_room: Node = null

var microphone: Microphone = null
## True while this player is holding a talk button.
var _talking: bool = false
var _audience: int = VoiceFrame.Audience.EVERYONE
var _sequence: int = 0
var _players: Array[AudioStreamPlayer] = []
## What this machine has PLAYED, for a harness: frames and samples, by kind. Counted where the audio lands.
var played_frames: int = 0
var played_samples: int = 0
var played_by_kind: Dictionary = {}
## Frames this machine refused to play, and why the last one was refused.
var refused: int = 0
var last_refusal: String = ""


func _ready() -> void:
	the_one_in_the_room = self
	microphone = Microphone.new()
	microphone.name = "Microphone"
	add_child(microphone)
	microphone.heard.connect(_on_heard)
	Net.voice_arrived.connect(_on_voice_arrived)
	var index: int = AudioServer.get_bus_index(BUS)
	if index < 0:
		index = AudioServer.bus_count
		AudioServer.add_bus(index)
		AudioServer.set_bus_name(index, BUS)
		AudioServer.set_bus_send(index, &"Master")


## HOLD THE BUTTON. `audience` is a `VoiceFrame.Audience`. Returns "" or why not, in words for whoever pressed it --
## which is how a player on no team learns that team talk is not available to them, rather than talking into nothing.
func start_talking(audience: int) -> String:
	if _talking:
		return ""
	if not Net.is_in_session:
		return "You are not in a session."
	if audience == VoiceFrame.Audience.TEAM and not TeamBoard.holds(Net.team_of(Sim.local_client_id())):
		return "You are not on a team yet. The host assigns them."
	var why: String = microphone.open()
	if not why.is_empty():
		return why
	_talking = true
	_audience = audience
	my_button_changed.emit(true, audience)
	return ""


## LET IT GO. The microphone closes with it: see `Microphone`, "open only while somebody is listening".
func stop_talking() -> void:
	if not _talking:
		return
	_talking = false
	microphone.close()
	my_button_changed.emit(false, _audience)


func is_talking() -> bool:
	return _talking


func audience() -> int:
	return _audience


## A FRAME FROM THE MICROPHONE. Encoded and offered; the host decides who hears it. Nothing here asks about teams --
## the sender says what it INTENDS and the host enforces it, because a client that decided its own audience could send
## to a team it is not on.
func _on_heard(samples: PackedFloat32Array, rate: int) -> void:
	if not _talking:
		return
	_sequence += 1
	var me: int = maxi(Sim.local_client_id(), 1)
	var bytes: PackedByteArray = VoiceFrame.encode(samples, rate, me, VoiceFrame.Kind.LIVE, _audience, _sequence)
	if bytes.is_empty():
		refused += 1
		last_refusal = "the microphone's samples did not fit a frame"
		return
	var why: String = Net.say_with_your_voice(bytes)
	if not why.is_empty():
		refused += 1
		last_refusal = why


## AUDIO FROM THE WIRE. Decoded, played, counted and announced with its label.
func _exit_tree() -> void:
	if the_one_in_the_room == self:
		the_one_in_the_room = null


func _on_voice_arrived(bytes: PackedByteArray) -> void:
	var frame: Dictionary = VoiceFrame.decode(bytes)
	if frame.has("why"):
		refused += 1
		last_refusal = String(frame["why"])
		return
	var samples: PackedInt32Array = frame["samples"]
	play(int(frame["speaker"]), int(frame["kind"]), samples)


## PLAY A BLOCK OF PCM FROM A NAMED SPEAKER, OF A NAMED KIND. Public, because the other carrier arrives here too: a
## generated line decoded from a `clip` document is played through this same door, so a listener has one place to hook.
func play(speaker: int, kind: int, samples: PackedInt32Array) -> void:
	if samples.is_empty():
		return
	var stream: AudioStreamWAV = VoiceFrame.stream(samples)
	var player := AudioStreamPlayer.new()
	player.name = "IntercomVoice"
	player.bus = BUS
	player.stream = stream
	add_child(player)
	player.play()
	_players.append(player)
	player.finished.connect(func() -> void:
		_players.erase(player)
		player.queue_free())
	announce(speaker, kind, samples.size())


## AUDIO OF A NAMED KIND HAS LANDED AND IS BEING HEARD. Counted here and announced here, whichever carrier brought it:
## `play` calls it for a live frame, and `Radio._play` calls it for a generated line that `Headphones` is playing on the
## Radio bus. This is the "one labelled arrival point" the design note above promises, and it is the only place the
## counts move.
func announce(speaker: int, kind: int, samples: int) -> void:
	played_frames += 1
	played_samples += samples
	played_by_kind[kind] = int(played_by_kind.get(kind, 0)) + 1
	heard.emit(speaker, kind, samples)


## HOW MANY FRAMES OF A KIND THIS MACHINE HAS PLAYED. The number a test asserts on, so that silence fails.
func frames_of_kind(kind: int) -> int:
	return int(played_by_kind.get(kind, 0))
