extends Node
class_name MusicBox
## Plays the host's small replicated music state against the shared simulation clock.

const DRIFT_SECONDS := 0.12
const SILENT_DB := -60.0

signal changed

var shelf: RecordShelf
var player: AudioStreamPlayer
var local_on := true
var missing_track := ""
var _track := ""
var _last_seek := 0.0


func _ready() -> void:
	if shelf == null:
		shelf = RecordShelf.new()
		add_child(shelf)
	player = AudioStreamPlayer.new()
	player.name = "Player"
	player.bus = &"Music"
	add_child(player)
	Net.music_changed.connect(_apply_state)
	_apply_state()


func _process(_delta: float) -> void:
	if _track.is_empty() or not player.playing:
		return
	var wanted := playback_offset(Net.music_state, server_frame(), Sim.tick_hz, player.stream.get_length())
	if absf(player.get_playback_position() - wanted) > DRIFT_SECONDS:
		player.seek(wanted)
		_last_seek = wanted
	player.volume_db = volume_db_at(Net.music_state, server_frame())


func _apply_state() -> void:
	var state: Dictionary = Net.music_state
	var wanted_track := String(state.get("track", ""))
	if wanted_track != _track:
		_track = wanted_track
		missing_track = ""
		player.stop()
		player.stream = null
		if not _track.is_empty():
			var stream := shelf.stream_for(_track)
			if stream == null:
				missing_track = "You have no track called '%s'." % _track
			else:
				player.stream = stream
				var offset := playback_offset(state, server_frame(), Sim.tick_hz, stream.get_length())
				player.play(offset)
				_last_seek = offset
	if player != null:
		player.volume_db = volume_db_at(state, server_frame())
	changed.emit()


func set_local_on(on: bool) -> void:
	local_on = on
	var bus := AudioServer.get_bus_index(&"Music")
	if bus >= 0:
		AudioServer.set_bus_mute(bus, not on)
	changed.emit()


func track_ids() -> Array[String]:
	return shelf.ids() if shelf != null else []


func status() -> String:
	if not missing_track.is_empty():
		return missing_track
	if _track.is_empty():
		return "Nothing is playing."
	return "%s · %s · %d%%" % [_track, time_words(playback_offset(Net.music_state, server_frame(), Sim.tick_hz,
		player.stream.get_length() if player.stream != null else 0.0)),
		int(round(db_to_linear(volume_db_at(Net.music_state, server_frame())) * 100.0))]


func last_seek_offset() -> float:
	return _last_seek


static func server_frame() -> float:
	if Sim.client != null and Sim.client.has_method("timing"):
		return float(Sim.client.timing().get("estimated_server_frame", Engine.get_physics_frames()))
	return float(Engine.get_physics_frames())


static func playback_offset(state: Dictionary, frame: float, tick_hz: float, length: float = 0.0) -> float:
	var seconds := maxf(0.0, (frame - float(state.get("started_frame", frame))) / maxf(tick_hz, 1.0))
	return fmod(seconds, length) if length > 0.0 else seconds


static func volume_db_at(state: Dictionary, frame: float) -> float:
	var frames := float(state.get("fade_frames", 0.0))
	if frames <= 0.0:
		return float(state.get("volume_to", 0.0))
	var amount := clampf((frame - float(state.get("fade_from_frame", frame))) / frames, 0.0, 1.0)
	return lerpf(float(state.get("volume_from", 0.0)), float(state.get("volume_to", 0.0)), amount)


static func time_words(seconds: float) -> String:
	return "%d:%02d" % [int(seconds) / 60, int(seconds) % 60]
