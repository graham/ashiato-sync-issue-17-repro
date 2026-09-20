extends Node
class_name RecordShelf
## Runtime music catalogue. Tracks are data beside the executable, not Godot resources in the PCK.

const ID_PATTERN := "^[a-z0-9][a-z0-9_-]{0,63}$"

var folder: String = ""
var tracks: Dictionary = {}
var disabled: Dictionary = {}


func _ready() -> void:
	if folder.is_empty():
		scan()


func scan(override_folder: String = "") -> void:
	tracks.clear()
	disabled.clear()
	folder = override_folder
	if folder.is_empty():
		for candidate in folders(_arguments(), OS.get_executable_path(), OS.has_feature("editor")):
			if DirAccess.dir_exists_absolute(candidate):
				folder = candidate
				break
	if folder.is_empty() or not DirAccess.dir_exists_absolute(folder):
		return
	var id_rule := RegEx.create_from_string(ID_PATTERN)
	for file_name in DirAccess.get_files_at(folder):
		if file_name.begins_with("_") or file_name.get_extension().to_lower() != "ogg":
			continue
		var id := file_name.get_basename().to_lower()
		if id_rule.search(id) == null:
			disabled[id] = "The file name is not a music id."
			continue
		var stream := AudioStreamOggVorbis.load_from_file(folder.path_join(file_name))
		if stream == null:
			disabled[id] = "The Ogg file could not be read."
			push_warning("[music] %s could not be read; disabled" % file_name)
			continue
		stream.loop = true
		tracks[id] = stream


func ids() -> Array[String]:
	var out: Array[String] = []
	for id in tracks.keys():
		out.append(String(id))
	out.sort()
	return out


func stream_for(id: String) -> AudioStream:
	return tracks.get(id) as AudioStream


static func valid_id(id: String) -> bool:
	return RegEx.create_from_string(ID_PATTERN).search(id) != null


static func folders(args: PackedStringArray, executable_path: String, is_editor: bool,
		project_music: String = "res://music") -> PackedStringArray:
	var out := PackedStringArray()
	for arg in args:
		if arg.begins_with("--music=") and arg.length() > 8:
			out.append(arg.substr(8))
			break
	out.append(executable_path.get_base_dir().path_join("music"))
	if is_editor:
		out.append(ProjectSettings.globalize_path(project_music))
	return out


static func _arguments() -> PackedStringArray:
	var out := OS.get_cmdline_user_args()
	for arg in OS.get_cmdline_args():
		if not out.has(arg):
			out.append(arg)
	return out
