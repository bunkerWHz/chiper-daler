extends Control

var is_pause_menu: bool = false
var _box: VBoxContainer
var _status: Label
var _page: String = "main"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_box = VBoxContainer.new()
	_box.custom_minimum_size.x = 440
	_box.add_theme_constant_override("separation", 12)
	center.add_child(_box)
	show_main()


func _clear(title: String, page: String) -> void:
	_page = page
	for child: Node in _box.get_children():
		_box.remove_child(child)
		child.queue_free()
	var heading := Label.new()
	heading.text = title
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 36)
	_box.add_child(heading)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 16)
	_box.add_child(_status)


func _button(title: String, action: Callable, disabled: bool = false) -> Button:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size.y = 46
	button.add_theme_font_size_override("font_size", 22)
	button.disabled = disabled
	button.pressed.connect(action)
	_box.add_child(button)
	return button


func show_main() -> void:
	_clear("Пауза" if is_pause_menu else "Chip and Dale", "main")
	var first: Button
	if is_pause_menu:
		first = _button("Продолжить", GameFlow.close_pause)
		_button("Сохранить контрольную точку", _save)
	else:
		if not GameFlow.read_save().is_empty():
			first = _button("Продолжить", _start.bind(true))
		var new_button := _button("Новая игра", _new_game)
		if first == null:
			first = new_button
		_button("Загрузить игру", _show_load)
	_button("Настройки", _show_settings)
	if is_pause_menu:
		_button("В главное меню", _confirm_return)
	_button("Выход", _confirm_quit)
	_focus.call_deferred(first)


func _start(saved: bool) -> void:
	if GameFlow.start_game(saved) != OK:
		_status.text = "Не удалось открыть уровень или сохранение."


func _new_game() -> void:
	if GameFlow.read_save().is_empty():
		_start(false)
	else:
		_confirm("Начать заново? Старый слот останется\nдо следующего ручного сохранения.", _start.bind(false))


func _show_load() -> void:
	_clear("Загрузить игру", "load")
	var saved := GameFlow.read_save()
	_status.text = "Нет доступных сохранений." if saved.is_empty() else "Контрольная точка • " + saved.date
	var load_button := _button("Загрузить контрольную точку", _start.bind(true), saved.is_empty())
	var note := Label.new()
	note.text = "Прототип: уровень создаётся заново.\nПредметы и состояние врагов не сохраняются."
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(note)
	var back := _button("Назад", show_main)
	_focus.call_deferred(back if saved.is_empty() else load_button)


func _save() -> void:
	_status.text = "Контрольная точка сохранена." if GameFlow.save_checkpoint() == OK else "Не удалось сохранить контрольную точку."


func _show_settings() -> void:
	_clear("Настройки", "settings")
	var slider := _volume_slider("Общая громкость", &"volume")
	_volume_slider("Звуковые эффекты (SFX)", &"sfx_volume")
	_volume_slider("Фоновая музыка", &"music_volume")
	var screen := CheckButton.new()
	var resolution_label := Label.new()
	resolution_label.text = "Разрешение окна"
	_box.add_child(resolution_label)
	var resolution_picker := OptionButton.new()
	resolution_picker.name = "ResolutionPicker"
	resolution_picker.custom_minimum_size.y = 40
	var resolutions := GameFlow.available_resolutions()
	for window_size: Vector2i in resolutions:
		resolution_picker.add_item("%d × %d" % [window_size.x, window_size.y])
	resolution_picker.select(resolutions.find(GameFlow.resolution))
	resolution_picker.disabled = GameFlow.fullscreen
	_box.add_child(resolution_picker)
	resolution_picker.item_selected.connect(func(index: int) -> void:
		GameFlow.resolution = resolutions[index]
		_store_settings())
	var resolution_note := Label.new()
	resolution_note.text = "В полном экране — разрешение монитора."
	resolution_note.add_theme_font_size_override("font_size", 16)
	_box.add_child(resolution_note)
	screen.text = "Полный экран"
	screen.button_pressed = GameFlow.fullscreen
	_box.add_child(screen)
	screen.toggled.connect(func(value: bool) -> void:
		GameFlow.fullscreen = value
		_store_settings()
		resolution_picker.disabled = value
		resolution_picker.select(resolutions.find(GameFlow.resolution)))
	var sync := CheckButton.new()
	sync.text = "Вертикальная синхронизация"
	sync.button_pressed = GameFlow.vsync
	_box.add_child(sync)
	sync.toggled.connect(func(value: bool) -> void:
		GameFlow.vsync = value
		_store_settings())
	_button("Назад", show_main)
	_focus.call_deferred(slider)


func _volume_slider(title: String, property: StringName) -> HSlider:
	var label := Label.new()
	label.text = "%s: %d%%" % [title, roundi(float(GameFlow.get(property)) * 100)]
	_box.add_child(label)
	var slider := HSlider.new()
	slider.name = property
	slider.max_value = 100
	slider.step = 1
	slider.value = float(GameFlow.get(property)) * 100
	slider.custom_minimum_size.y = 28
	_box.add_child(slider)
	slider.value_changed.connect(func(value: float) -> void:
		GameFlow.set(property, value / 100.0)
		label.text = "%s: %d%%" % [title, roundi(value)]
		_store_settings())
	return slider


func _store_settings() -> void:
	_status.text = "Настройки сохранены." if GameFlow.save_settings() == OK else "Ошибка записи настроек."


func _confirm_return() -> void:
	_confirm("Вернуться в меню?\nНесохранённый прогресс будет потерян.", _return_to_menu)


func _return_to_menu() -> void:
	if GameFlow.return_to_menu() != OK:
		_status.text = "Не удалось открыть главное меню."


func _confirm_quit() -> void:
	_confirm("Выйти из игры?" + ("\nНесохранённый прогресс будет потерян." if is_pause_menu else ""), get_tree().quit)


func _confirm(message: String, action: Callable) -> void:
	_clear("Подтверждение", "confirm")
	_status.text = message
	_button("Да", action)
	_focus.call_deferred(_button("Отмена", show_main))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		if _page != "main":
			show_main()
		elif is_pause_menu:
			GameFlow.close_pause()


func _focus(control: Control) -> void:
	if is_instance_valid(control) and control.is_inside_tree():
		control.grab_focus()

