extends SceneTree

# Run with an isolated APPDATA directory so real saves/settings are untouched.
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _run() -> void:
	var flow := root.get_node("GameFlow")
	check(change_scene_to_file(flow.MENU) == OK, "Menu loads")
	await process_frame
	await process_frame
	var menu := current_scene
	check(menu.get_node("Background/Color") is ColorRect, "Replaceable background")
	menu._show_load()
	check(menu._status.text == "Нет доступных сохранений.", "Empty save slot")
	menu._show_settings()
	var picker := menu._box.get_node("ResolutionPicker") as OptionButton
	var choices: Array[Vector2i] = flow.available_resolutions()
	picker.select(0)
	picker.item_selected.emit(0)
	check(flow.resolution == choices[0], "Picker applies resolution")
	flow.resolution = Vector2i(1, 1)
	flow.load_settings()
	check(flow.resolution == choices[0], "Resolution reloads from disk")
	if DisplayServer.get_name() != "headless":
		await process_frame
		check(DisplayServer.window_get_size() == choices[0], "Window resized")
		flow.fullscreen = true
		flow.apply_settings()
		await process_frame
		menu._show_settings()
		check(menu._box.get_node("ResolutionPicker").disabled, "Fullscreen disables window size picker")
		flow.fullscreen = false
		flow.apply_settings()
		await process_frame
		check(DisplayServer.window_get_size() == choices[0], "Window size restored after fullscreen")
	flow.resolution = choices[mini(1, choices.size() - 1)]
	flow.volume = 0.35
	check(flow.save_settings() == OK, "Settings write succeeds")
	var settings := ConfigFile.new()
	check(settings.load(flow.SETTINGS_PATH) == OK, "Settings persist")
	check(is_equal_approx(settings.get_value("audio", "volume"), 0.35), "Volume survives disk round trip")
	check(flow.start_game() == OK, "New game starts")
	await process_frame
	await physics_frame
	await process_frame
	var respawn: PlayerRespawnComponent
	for node: Node in current_scene.find_children("*", "", true, false):
		if node is PlayerRespawnComponent:
			respawn = node
			break
	check(respawn != null, "Level has player checkpoint")
	if respawn == null:
		quit(1)
		return
	var checkpoint := respawn.get_checkpoint_position() + Vector2(25, 0)
	respawn.set_checkpoint_position(checkpoint)
	var cancel := InputEventAction.new()
	cancel.action = "ui_cancel"
	cancel.pressed = true
	flow._unhandled_input(cancel)
	check(paused and flow._pause_layer != null, "Pause menu pauses gameplay")
	check(flow.save_checkpoint() == OK, "Checkpoint writes")
	check(flow.read_save().get("checkpoint") == checkpoint, "Checkpoint survives disk round trip")
	check(flow.return_to_menu() == OK, "Return to menu succeeds")
	await process_frame
	await process_frame
	check(not paused, "Returning releases pause")
	check(flow.start_game(true) == OK, "Saved game loads")
	await process_frame
	await process_frame
	check(PlayerRespawnComponent._scene_checkpoints.get(flow.FIRST_LEVEL) == checkpoint, "Loading restores checkpoint")
	flow.return_to_menu()
	await process_frame
	await process_frame
	check(flow.start_game(false) == OK, "Another new game starts")
	await process_frame
	await process_frame
	check(PlayerRespawnComponent._scene_checkpoints.get(flow.FIRST_LEVEL) != checkpoint, "New game clears old checkpoint")
	var invalid := ConfigFile.new()
	invalid.set_value("save", "version", 1)
	invalid.set_value("save", "scene", flow.FIRST_LEVEL)
	invalid.set_value("save", "checkpoint", "broken")
	invalid.save("user://invalid.cfg")
	check(flow.read_save("user://invalid.cfg").is_empty(), "Invalid save rejected")
	flow.return_to_menu()
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		current_scene._show_settings()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/settings-preview.png")
	DirAccess.remove_absolute(flow.SAVE_PATH)
	DirAccess.remove_absolute(flow.SETTINGS_PATH)
	DirAccess.remove_absolute("user://invalid.cfg")
	print("Menu runtime checks: %d failures" % failures)
	quit(1 if failures else 0)
