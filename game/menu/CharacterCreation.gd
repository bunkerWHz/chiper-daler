extends Control

const CreationData := preload("res://game/menu/CharacterCreationData.gd")
var draft := CreationData.new()
var _values: Dictionary = {}
var _minus: Dictionary = {}
var _plus: Dictionary = {}
var _points: Label
var _status: Label
var _weight: Label
var _start_button: Button

func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color("0e1622")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	margin.add_child(layout)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)
	var page := VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 14)
	scroll.add_child(page)
	_label(page, "Создание персонажа", 32)
	_label(page, "Darklight • свободное развитие без классов", 18)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 36)
	page.add_child(columns)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 360
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 10)
	columns.add_child(left)
	_label(left, "Имя героя", 20)
	var name_input := LineEdit.new()
	name_input.name = "CharacterName"
	name_input.placeholder_text = "Введите имя"
	name_input.max_length = 24
	name_input.custom_minimum_size.y = 42
	left.add_child(name_input)
	name_input.text_changed.connect(func(value: String) -> void:
		draft.character_name = value
		_refresh())
	_points = _label(left, "", 22)
	for key: String in CreationData.ATTRIBUTES:
		var row := HBoxContainer.new()
		left.add_child(row)
		var title := _label(row, CreationData.ATTRIBUTES[key], 20)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_minus[key] = _button(row, "−", _change.bind(key, -1))
		_values[key] = _label(row, "1", 22)
		_values[key].custom_minimum_size.x = 38
		_values[key].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_plus[key] = _button(row, "+", _change.bind(key, 1))
	_button(left, "Сбросить очки", func() -> void:
		draft.reset_attributes()
		_refresh())
	_label(left, "Минимум 1 в каждом стате. Всего — 10.", 16)
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 460
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 12)
	columns.add_child(right)
	_label(right, "Стартовое снаряжение", 24)
	_picker(right, "Оружие", CreationData.WEAPONS.keys(), func(index: int) -> void:
		draft.weapon_index = index
		_refresh())
	_picker(right, "Комплект брони · 7 предметов", CreationData.ARMOR.keys(), func(index: int) -> void:
		draft.armor_index = index
		_refresh())
	_weight = _label(right, "", 18)
	_weight.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var note := _label(right, "Во всех наборах: фляги здоровья и маны.\nОружие и броню можно сочетать свободно.\n\nEND уже влияет на здоровье и нагрузку,\nWIS — на ману. Остальные связи статов\nс боем будут добавлены позднее.", 17)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Keep validation and actions outside scrolling content: longer messages and
	# equipment warnings must never push the buttons below the viewport.
	_status = _label(layout, "", 18)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 16)
	layout.add_child(actions)
	_button(actions, "Назад", _back)
	_start_button = _button(actions, "Начать приключение", _start)
	_refresh()
	name_input.grab_focus()

func _label(parent: Node, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(44, 40)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _picker(parent: Node, title: String, choices: Array, action: Callable) -> void:
	_label(parent, title, 18)
	var picker := OptionButton.new()
	picker.name = "WeaponPicker" if title == "Оружие" else "ArmorPicker"
	picker.custom_minimum_size.y = 44
	for choice: String in choices:
		picker.add_item(choice)
	picker.item_selected.connect(action)
	parent.add_child(picker)

func _change(key: String, delta: int) -> void:
	draft.change_attribute(key, delta)
	_refresh()

func _refresh() -> void:
	_points.text = "Свободных очков: %d" % draft.remaining_points()
	for key: String in CreationData.ATTRIBUTES:
		_values[key].text = str(draft.attributes[key])
		_minus[key].disabled = draft.attributes[key] <= 1
		_plus[key].disabled = draft.remaining_points() <= 0
	var config := CharacterDerivedStatsConfig.new()
	var capacity := maxf(1.0, config.base_max_equip_load + (draft.attributes.endurance - config.reference_endurance) * config.equip_load_per_endurance)
	var weight := draft.equipment_weight()
	_weight.text = "Вес экипировки: %.1f / %.1f\n%s" % [weight, capacity, "Перегруз: увеличьте выносливость или выберите более лёгкую броню." if weight > capacity else "Нагрузка в пределах допустимой."]
	_status.text = draft.validation_error()
	_start_button.disabled = not _status.text.is_empty()

func _start() -> void:
	var error := GameFlow.start_created_game(draft)
	if error != OK:
		_status.text = "Не удалось начать игру: " + error_string(error)

func _back() -> void:
	get_tree().change_scene_to_file(GameFlow.MENU)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		_back()
