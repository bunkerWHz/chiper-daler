extends Node

const CreationData := preload("res://game/menu/CharacterCreationData.gd")

const MENU := "res://game/menu/MainMenu.tscn"
const CHARACTER_CREATION := "res://game/menu/CharacterCreation.tscn"
const FIRST_LEVEL := "res://tests/MovementSandbox.tscn"
const SAVE_PATH := "user://checkpoint.cfg"
const SETTINGS_PATH := "user://settings.cfg"
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(640, 360), Vector2i(960, 540), Vector2i(1280, 720),
	Vector2i(1366, 768), Vector2i(1600, 900), Vector2i(1920, 1080),
	Vector2i(2560, 1440), Vector2i(3840, 2160),
]

var volume: float = 0.8
var sfx_volume: float = 1.0
var music_volume: float = 1.0
var fullscreen: bool = false
var vsync: bool = true
var resolution := Vector2i(1280, 720)
var _pause_layer: CanvasLayer
var _lease: PauseLease
var saves := preload("res://features/save/SaveService.gd").new()
var _save_warning: CanvasLayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	saves.name = "Saves"
	add_child(saves)
	saves.save_finished.connect(_show_save_result)
	get_tree().auto_accept_quit = false
	load_settings()
	apply_settings()


func load_settings() -> void:
	var settings := ConfigFile.new()
	if settings.load(SETTINGS_PATH) == OK:
		volume = clampf(float(settings.get_value("audio", "volume", 0.8)), 0.0, 1.0)
		sfx_volume = clampf(float(settings.get_value("audio", "sfx_volume", 1.0)), 0.0, 1.0)
		music_volume = clampf(float(settings.get_value("audio", "music_volume", 1.0)), 0.0, 1.0)
		fullscreen = bool(settings.get_value("video", "fullscreen", false))
		vsync = bool(settings.get_value("video", "vsync", true))
		var saved_resolution: Variant = settings.get_value("video", "resolution", Vector2i(1280, 720))
		resolution = saved_resolution if saved_resolution is Vector2i else Vector2i(1280, 720)
	_validate_resolution()


func available_resolutions() -> Array[Vector2i]:
	if DisplayServer.get_name() == "headless":
		return RESOLUTIONS.duplicate()
	var usable := DisplayServer.screen_get_usable_rect().size
	var result: Array[Vector2i] = []
	for size: Vector2i in RESOLUTIONS:
		# Leave room for the window border and title bar.
		if size.x <= usable.x - 16 and size.y <= usable.y - 48:
			result.append(size)
	return result if not result.is_empty() else [Vector2i(640, 360)]


func _validate_resolution() -> void:
	var choices := available_resolutions()
	if resolution not in choices:
		resolution = choices[0]
		for size: Vector2i in choices:
			if size.x <= 1280:
				resolution = size


func apply_settings() -> void:
	_apply_bus_volume(&"Master", volume)
	_apply_bus_volume(&"SFX", sfx_volume)
	_apply_bus_volume(&"Music", music_volume)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
		if not fullscreen:
			_validate_resolution()
			if DisplayServer.window_get_size() != resolution:
				DisplayServer.window_set_size(resolution)
				var usable := DisplayServer.screen_get_usable_rect()
				var center_offset := Vector2i(Vector2(usable.size - resolution) * 0.5)
				DisplayServer.window_set_position(usable.position + center_offset)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)


func _apply_bus_volume(bus_name: StringName, value: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		push_error("Missing audio bus: " + bus_name)
		return
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value, 0.0001)))
	AudioServer.set_bus_mute(index, value <= 0.0)


func save_settings() -> Error:
	apply_settings()
	var settings := ConfigFile.new()
	settings.set_value("audio", "volume", volume)
	settings.set_value("audio", "sfx_volume", sfx_volume)
	settings.set_value("audio", "music_volume", music_volume)
	settings.set_value("video", "fullscreen", fullscreen)
	settings.set_value("video", "vsync", vsync)
	settings.set_value("video", "resolution", resolution)
	return settings.save(SETTINGS_PATH)


func read_save(path: String = SAVE_PATH) -> Dictionary:
	return saves.store.read_save(path)


func save_checkpoint(path: String = SAVE_PATH) -> Error:
	return saves.save_now(path)


func start_created_game(draft: RefCounted) -> Error:
	if not draft is CreationData:
		return ERR_INVALID_PARAMETER
	if not draft.validation_error().is_empty():
		return ERR_INVALID_PARAMETER
	return start_game(false, draft.player_state())


func start_game(from_save: bool = false, initial_player: Dictionary = {}) -> Error:
	var saved := read_save() if from_save else {}
	if not from_save and not initial_player.is_empty():
		if not saves.store.codec.validate(initial_player):
			return ERR_INVALID_DATA
		saved = {"player": initial_player}
	if from_save and saved.is_empty():
		return ERR_FILE_CORRUPT
	var scene_path: String = saved.get("scene", FIRST_LEVEL)
	var packed := load(scene_path) as PackedScene
	if packed == null:
		return ERR_CANT_OPEN
	close_pause()
	PlayerRespawnComponent.clear_saved_checkpoints()
	if from_save:
		PlayerRespawnComponent._scene_checkpoints[scene_path] = saved.checkpoint
	saves.prepare(saved)
	return get_tree().change_scene_to_packed(packed)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel") or event.is_echo():
		return
	var scene := get_tree().current_scene
	if scene == null or scene.scene_file_path in [MENU, CHARACTER_CREATION]:
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
	if saves.active:
		var error := saves.save_now()
		if error != OK:
			return error
	saves.active = false
	close_pause()
	return get_tree().change_scene_to_file(MENU)


func quit_game() -> Error:
	if saves.active:
		var error := saves.save_now()
		if error != OK:
			return error
	get_tree().quit()
	return OK


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if quit_game() != OK and _pause_layer == null:
			var event := InputEventAction.new()
			event.action = "ui_cancel"
			event.pressed = true
			_unhandled_input(event)


func _show_save_result(error: Error) -> void:
	if error == OK:
		if is_instance_valid(_save_warning):
			_save_warning.queue_free()
			_save_warning = null
		return
	if is_instance_valid(_save_warning):
		return
	_save_warning = CanvasLayer.new()
	_save_warning.layer = 110
	add_child(_save_warning)
	var label := Label.new()
	label.text = "Не удалось сохранить игру. Повторяем попытку…"
	label.position = Vector2(20, 20)
	label.add_theme_color_override("font_color", Color(1.0, 0.65, 0.35))
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	_save_warning.add_child(label)
