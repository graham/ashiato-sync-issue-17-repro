extends VBoxContainer
class_name MusicPage
## The clipboard's view of a RecordShelf. It announces; FlightLevel and Net decide.

const FADE_SECONDS := 5.0

signal chose_track(id: String)
signal chose_stop
signal chose_fade(target_db: float, seconds: float)

var _tracks := VBoxContainer.new()
var _volume := HSlider.new()
var _readout := Label.new()
var _authority := Label.new()
var _action_buttons: Array[Button] = []
var _ids: Array[String] = []
var _can_choose := false


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	_tracks.add_theme_constant_override("separation", 4)
	add_child(_tracks)
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 8)
	var stop := Button.new()
	stop.name = "Stop"
	stop.text = "STOP"
	stop.pressed.connect(func(): chose_stop.emit())
	controls.add_child(stop)
	_action_buttons.append(stop)
	var fade_in := Button.new()
	fade_in.name = "FadeIn"
	fade_in.text = "FADE IN"
	fade_in.pressed.connect(func(): chose_fade.emit(_volume.value, FADE_SECONDS))
	controls.add_child(fade_in)
	_action_buttons.append(fade_in)
	var fade_out := Button.new()
	fade_out.name = "FadeOut"
	fade_out.text = "FADE OUT"
	fade_out.pressed.connect(func(): chose_fade.emit(Net.MUSIC_DB_MIN, FADE_SECONDS))
	controls.add_child(fade_out)
	_action_buttons.append(fade_out)
	add_child(controls)
	var volume_row := HBoxContainer.new()
	var word := Label.new()
	word.text = "VOLUME"
	volume_row.add_child(word)
	_volume.name = "Volume"
	_volume.min_value = -40.0
	_volume.max_value = 0.0
	_volume.step = 1.0
	_volume.value = -12.0
	_volume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	volume_row.add_child(_volume)
	add_child(volume_row)
	_readout.name = "Readout"
	_readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_readout)
	_authority.name = "Authority"
	_authority.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_authority)
	_rebuild_tracks()


func show_catalog(ids: Array[String]) -> void:
	_ids = ids.duplicate()
	_rebuild_tracks()


func show_state(state: Dictionary, status: String, can_choose: bool) -> void:
	_can_choose = can_choose
	_volume.set_value_no_signal(float(state.get("volume_to", -12.0)))
	_readout.text = status
	_authority.text = "You choose music for everybody." if can_choose \
		else "The host chooses music and fades for everybody."
	_authority.add_theme_color_override("font_color", BoardStyle.DIM if can_choose else BoardStyle.AMBER)
	for child in _tracks.get_children():
		var button := child as BaseButton
		if button != null:
			button.disabled = not can_choose
	for button in _action_buttons:
		button.disabled = not can_choose


func track_buttons() -> Array[Button]:
	var out: Array[Button] = []
	for child in _tracks.get_children():
		out.append(child as Button)
	return out


func readout() -> String:
	return _readout.text


func _rebuild_tracks() -> void:
	for child in _tracks.get_children():
		child.free()
	if _ids.is_empty():
		var none := Label.new()
		none.text = "Put .ogg files in the music folder beside the game."
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_tracks.add_child(none)
		return
	for id in _ids:
		var button := Button.new()
		button.name = "Track_%s" % id
		button.text = "PLAY  %s" % id.to_upper()
		button.custom_minimum_size.y = BoardStyle.reach(38.0)
		button.add_theme_font_size_override("font_size", BoardStyle.pressed_text(18))
		button.disabled = not _can_choose
		button.pressed.connect(func(): chose_track.emit(id))
		_tracks.add_child(button)
