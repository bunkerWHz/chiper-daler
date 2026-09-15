extends Node

const MENU := "res://game/menu/MainMenu.tscn"
const FIRST_LEVEL := "res://tests/MovementSandbox.tscn"
const SAVE_PATH := "user://checkpoint.cfg"
const SETTINGS_PATH := "user://settings.cfg"

var volume: float = 0.8
var fullscreen: bool = false
var vsync: bool = true
var _pause_layer: CanvasLayer
var _lease: PauseLease


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var settings := ConfigFile.new()
	if settings.load(SETTINGS_PATH) == OK:
		volume = clampf(float(settings.get_value("audio", "volume", 0.8)), 0.0, 1.0)
		fullscreen = bool(settings.get_value("video", "fullscreen", false))
		vsync = bool(settings.get_value("video", "vsync", true))
	apply_settings()


func apply_settings() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(0, volume <= 0.0)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)


func save_settings() -> Error:
	apply_settings()
	var settings := ConfigFile.new()
	settings.set_value("audio", "volume", volume)
	settings.set_value("video", "fullscreen", fullscreen)
	settings.set_value("video", "vsync", vsync)
	return settings.save(SETTINGS_PATH)


func read_save(path: String = SAVE_PATH) -> Dictionary:
	var data := ConfigFile.new()
	if data.load(path) != OK or data.get_value("save", "version", 0) != 1:
		return {}
	var scene: Variant = data.get_value("save", "scene", "")
	var position: Variant = data.get_value("save", "checkpoint")
	if not scene is String or not scene.begins_with("res://") or not scene.ends_with(".tscn"):
		return {}
	if not ResourceLoader.exists(scene, "PackedScene") or not position is Vector2 or not position.is_finite():
		return {}
	return {"scene": scene, "checkpoint": position, "date": str(data.get_value("save", "date", ""))}


func save_checkpoint(path: String = SAVE_PATH) -> Error:
	var scene := get_tree().current_scene
	if scene == null:
		return ERR_UNAVAILABLE
	for node: Node in scene.find_children("*", "", true, false):
		if node is PlayerRespawnComponent and node.is_enabled:
			var data := ConfigFile.new()
			data.set_value("save", "version", 1)
			data.set_value("save", "scene", scene.scene_file_path)
			data.set_value("save", "checkpoint", node.get_checkpoint_position())
			data.set_value("save", "date", Time.get_datetime_string_from_system().replace("T", " "))
			return data.save(path)
	return ERR_UNAVAILABLE


func start_game(from_save: bool = false) -> Error:
	var saved := read_save() if from_save else {}
	if from_save and saved.is_empty():
		return ERR_FILE_CORRUPT
	var scene_path: String = saved.get("scene", FIRST_LEVEL)
	var packed := load(scene_path) as PackedScene
	if packed == null:
		return ERR_CANT_OPEN
	PlayerRespawnComponent.clear_saved_checkpoints()
	if from_save:
		PlayerRespawnComponent._scene_checkpoints[scene_path] = saved.checkpoint
	return get_tree().change_scene_to_packed(packed)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel") or event.is_echo():
		return
	var scene := get_tree().current_scene
	if scene == null or scene.scene_file_path == MENU:
		return
	get_viewport().set_input_as_handled()
	if _pause_layer != null:
		close_pause()
	elif not get_tree().paused:
		_lease = PauseLease.acquire(get_tree())
		_pause_layer = CanvasLayer.new()
		_pause_layer.layer = 100
		add_child(_pause_layer)
		var menu := load(MENU).instantiate() as Control
		menu.set("is_pause_menu", true)
		_pause_layer.add_child(menu)


func close_pause() -> void:
	if _pause_layer != null:
		_pause_layer.queue_free()
		_pause_layer = null
	if _lease != null:
		_lease.release()
		_lease = null


func return_to_menu() -> Error:
	close_pause()
	return get_tree().change_scene_to_file(MENU)
