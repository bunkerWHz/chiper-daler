extends CanvasLayer

var shelter: RestPoint
var visitor: Actor
var _lease: PauseLease
var _balance: Label
var _actions: VBoxContainer
var _feedback: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 105
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.02, 0.02, 0.03, 0.85)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	panel.theme = preload("res://features/inventory/ui/InventoryTheme.tres")
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)
	var title := Label.new()
	title.text = "УБЕЖИЩЕ"
	title.add_theme_font_size_override("font_size", 26)
	content.add_child(title)
	var currency_row := HBoxContainer.new()
	content.add_child(currency_row)
	var icon := TextureRect.new()
	icon.texture = preload("res://assets/items/Amber_Shards.png")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(40, 28)
	currency_row.add_child(icon)
	_balance = Label.new()
	_balance.modulate = Color(1.0, 0.72, 0.3)
	currency_row.add_child(_balance)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(510, 340)
	content.add_child(scroll)
	_actions = VBoxContainer.new()
	_actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_actions.add_theme_constant_override("separation", 8)
	scroll.add_child(_actions)
	_feedback = Label.new()
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_feedback)
	var close := Button.new()
	close.text = "Вернуться в мир · Esc"
	close.pressed.connect(queue_free)
	content.add_child(close)
	_lease = PauseLease.acquire(get_tree())
	_refresh()
	close.grab_focus()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()

func _process(_delta: float) -> void:
	if not is_instance_valid(visitor):
		queue_free()
		return
	var inventory_menu := visitor.get_component(InventoryMenuComponent) as InventoryMenuComponent
	if inventory_menu != null and inventory_menu.is_open():
		queue_free()

func _exit_tree() -> void:
	if _lease != null:
		_lease.release()

func _refresh() -> void:
	if not is_instance_valid(visitor) or not is_instance_valid(shelter):
		queue_free()
		return
	var inventory := visitor.get_component(InventoryComponent) as InventoryComponent
	_balance.text = "Янтарные осколки: %d" % inventory.get_amber()
	for child in _actions.get_children():
		_actions.remove_child(child)
		child.queue_free()
	var cost := shelter.get_level_cost(visitor)
	_button("Повысить уровень · %d осколков" % cost, shelter.buy_level.bind(visitor), cost <= 0 or inventory.get_amber() < cost)
	for index in shelter.shop_weapons.size():
		var item := shelter.shop_weapons[index]
		if item == null:
			continue
		cost = shelter.get_weapon_price(index)
		_button("Купить %s · %d" % [item.display_name, cost], shelter.buy_weapon.bind(visitor, index), inventory.get_amber() < cost)
	var equipment := visitor.get_component(EquipmentComponent) as EquipmentComponent
	var weapon := equipment.get_equipped_item(ItemData.EquipSlot.MAIN_HAND) if equipment != null else null
	if weapon != null:
		var level := inventory.get_weapon_upgrade(weapon.id)
		cost = shelter.upgrade_base_cost * (level + 1)
		_button("Улучшить %s +%d · %d" % [weapon.display_name, level, cost], shelter.upgrade_equipped_weapon.bind(visitor), level >= 5 or inventory.get_amber() < cost)
		var hint := Label.new()
		hint.text = "+10% урона за ступень, до +5. Для всех копий этого оружия."
		hint.add_theme_font_size_override("font_size", 12)
		_actions.add_child(hint)

func _button(text: String, action: Callable, unavailable: bool) -> void:
	var button := Button.new()
	button.text = text
	button.disabled = unavailable
	button.pressed.connect(func() -> void:
		var success: bool = action.call()
		_feedback.text = "Готово." if success else "Не удалось: проверьте место в инвентаре и запас осколков."
		_refresh()
	)
	_actions.add_child(button)
