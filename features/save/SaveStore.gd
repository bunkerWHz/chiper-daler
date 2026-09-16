extends RefCounted

const VERSION := 4
const MAX_BYTES := 4 * 1024 * 1024
var codec := preload("res://features/save/PlayerSaveData.gd").new()


func read_save(path: String) -> Dictionary:
	var result := _read_file(path)
	if result.is_empty():
		result = _read_file(path + ".bak")
		if not result.is_empty():
			result["recovered"] = true
	return result


func _read_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES:
		return {}
	var data := ConfigFile.new()
	if data.parse(file.get_as_text()) != OK:
		return {}
	var version: Variant = data.get_value("save", "version", 0)
	if not version is int or version < 1 or version > VERSION:
		return {}
	var result := {}
	for key: String in data.get_section_keys("save"):
		result[key] = data.get_value("save", key)
	if not result.get("scene") is String or not result.scene.begins_with("res://") or not result.scene.ends_with(".tscn"):
		return {}
	if not ResourceLoader.exists(result.scene, "PackedScene") or not result.get("checkpoint") is Vector2 or not result.checkpoint.is_finite():
		return {}
	if version == 1:
		# The old checkpoint prototype had no character/world data to migrate.
		result.merge({"player": {}, "world": {}, "rest_id": "", "play_seconds": 0}, true)
	if not result.get("rest_id") is String or not codec.validate(result.get("player")):
		return {}
	if version >= 2 and not result.player.has_all(codec.component_types.keys()):
		return {}
	if not result.get("world") is Dictionary or not codec._plain_data(result.world):
		return {}
	if not codec._count(result.get("play_seconds")):
		return {}
	if version < 3:
		result["lost_amber"] = {}
	if not _valid_lost_amber(result.get("lost_amber")):
		return {}
	result["date"] = str(result.get("date", ""))
	return result


func _valid_lost_amber(loss: Variant) -> bool:
	if not loss is Dictionary:
		return false
	if loss.is_empty():
		return true
	return (loss.get("scene") is String and loss.scene.begins_with("res://")
		and loss.scene.ends_with(".tscn") and ResourceLoader.exists(loss.scene, "PackedScene")
		and loss.get("position") is Vector2 and loss.position.is_finite()
		and codec._count(loss.get("amount")) and loss.amount > 0)


func write_save(path: String, snapshot: Dictionary) -> Error:
	var data := ConfigFile.new()
	for key: String in snapshot:
		data.set_value("save", key, snapshot[key])
	data.set_value("save", "version", VERSION)
	var temporary := path + ".tmp"
	var error := data.save(temporary)
	if error != OK:
		return error
	if _read_file(temporary).is_empty():
		return ERR_INVALID_DATA
	# Only a validated previous primary may replace the good backup.
	if not _read_file(path).is_empty():
		error = DirAccess.copy_absolute(path, path + ".bak")
		if error != OK:
			return error
	# Same-directory rename replaces the primary only after a complete write.
	return DirAccess.rename_absolute(temporary, path)
