extends Node
## SaveSystem : point de sauvegarde unique (checkpoint) au format JSON dans user://.

const SAVE_PATH: String = "user://savegame.json"
const SAVE_VERSION: int = 1


func has_save() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	return not read_save().is_empty()


func write_save(data: Dictionary) -> bool:
	var payload := data.duplicate(true)
	payload["version"] = SAVE_VERSION
	payload["timestamp"] = Time.get_datetime_string_from_system()
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Sauvegarde impossible : %s" % error_string(FileAccess.get_open_error()))
		return false
	f.store_string(JSON.stringify(payload, "\t"))
	f.close()
	return true


func read_save() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var text := FileAccess.get_file_as_string(SAVE_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return {}
	var d: Dictionary = parsed
	if int(d.get("version", 0)) != SAVE_VERSION:
		return {}
	return d


func erase_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
