extends Component
class_name QuickAccessHUDComponent

const SLOT_COUNT := 8
const ICON_SIZE := Vector2(64.0, 64.0)
const SLOT_SIZE := Vector2(68.0, 68.0)

var _quick_access: QuickAccessComponent
var _inventory: InventoryComponent
var _equipment: EquipmentComponent
var _slot_views: Array[PanelContainer] = []
var _key_labels: Array[Label] = []
var _quantity_labels: Array[Label] = []
var _icons: Array[TextureRect] = []
var _slots_container: HBoxContainer


func on_initialize() -> void:
	_quick_access = actor.get_component(QuickAccessComponent) as QuickAccessComponent
	_inventory = actor.get_component(InventoryComponent) as InventoryComponent
	_equipment = actor.get_component(EquipmentComponent) as EquipmentComponent
	if _quick_access == null or _inventory == null or _equipment == null:
		push_error("QuickAccessHUDComponent requires quick access, inventory, and equipment")
		disable()


func _ready() -> void:
	_slots_container = get_node_or_null(
		"CanvasLayer/TopMargin/Slots"
	) as HBoxContainer
	if not is_enabled or _slots_container == null:
		return

	_create_slot_views()
	_connect_signals()
	refresh()


func refresh() -> void:
	if _slots_container == null:
		return
	for slot_index in SLOT_COUNT:
		_update_slot_view(slot_index, get_slot_display(slot_index))


func get_slot_display(slot_index: int) -> Dictionary:
	var result := {
		"key": str(slot_index + 1),
		"title": "Empty",
		"detail": "",
		"quantity": "",
		"icon": ItemData.PLACEHOLDER_ICON,
		"available": false,
		"active": slot_index == _quick_access.get_active_slot(),
		"equipped": false,
	}
	var slot := _quick_access.get_slot(slot_index)
	if slot == null:
		return result

	match slot.kind:
		QuickAccessSlot.Kind.WEAPON_SET:
			_apply_weapon_set_display(result, slot.weapon_set)
		QuickAccessSlot.Kind.ITEM:
			_apply_item_display(result, slot.item_id)
		QuickAccessSlot.Kind.EMPTY:
			pass
	return result


func get_slot_view(slot_index: int) -> PanelContainer:
	if slot_index < 0 or slot_index >= _slot_views.size():
		return null
	return _slot_views[slot_index]


func _create_slot_views() -> void:
	for child: Node in _slots_container.get_children():
		child.queue_free()
	_slot_views.clear()
	_key_labels.clear()
	_quantity_labels.clear()
	_icons.clear()

	for slot_index in SLOT_COUNT:
		var panel := PanelContainer.new()
		panel.name = "Slot%d" % (slot_index + 1)
		panel.custom_minimum_size = SLOT_SIZE
		panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 2)
		margin.add_theme_constant_override("margin_top", 2)
		margin.add_theme_constant_override("margin_right", 2)
		margin.add_theme_constant_override("margin_bottom", 2)
		panel.add_child(margin)

		var content := Control.new()
		content.custom_minimum_size = ICON_SIZE
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_child(content)

		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(icon)

		var key_label := Label.new()
		key_label.name = "Key"
		key_label.offset_left = 3.0
		key_label.offset_top = 1.0
		key_label.offset_right = 23.0
		key_label.offset_bottom = 20.0
		key_label.add_theme_font_size_override("font_size", 11)
		key_label.add_theme_color_override("font_outline_color", Color.BLACK)
		key_label.add_theme_constant_override("outline_size", 3)
		key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(key_label)

		var quantity_label := Label.new()
		quantity_label.name = "Quantity"
		quantity_label.anchor_left = 1.0
		quantity_label.anchor_top = 1.0
		quantity_label.anchor_right = 1.0
		quantity_label.anchor_bottom = 1.0
		quantity_label.offset_left = -43.0
		quantity_label.offset_top = -21.0
		quantity_label.offset_right = -3.0
		quantity_label.offset_bottom = -1.0
		quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		quantity_label.add_theme_font_size_override("font_size", 11)
		quantity_label.add_theme_color_override("font_outline_color", Color.BLACK)
		quantity_label.add_theme_constant_override("outline_size", 3)
		quantity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(quantity_label)

		_slots_container.add_child(panel)
		_slot_views.append(panel)
		_key_labels.append(key_label)
		_quantity_labels.append(quantity_label)
		_icons.append(icon)


func _connect_signals() -> void:
	_quick_access.active_slot_changed.connect(_on_quick_access_changed)
	_quick_access.slot_assignment_changed.connect(_on_slot_assignment_changed)
	_inventory.inventory_changed.connect(_on_inventory_changed)
	_equipment.weapon_set_changed.connect(_on_weapon_set_changed)
	_equipment.loadout_item_changed.connect(_on_loadout_item_changed)


func _update_slot_view(slot_index: int, display: Dictionary) -> void:
	if slot_index < 0 or slot_index >= _slot_views.size():
		return
	var panel := _slot_views[slot_index]
	var key_label := _key_labels[slot_index]
	var quantity_label := _quantity_labels[slot_index]
	var icon := _icons[slot_index]

	key_label.text = String(display.key)
	quantity_label.text = String(display.quantity)
	icon.texture = display.icon as Texture2D
	panel.visible = bool(display.available)
	panel.modulate = Color.WHITE if bool(display.available) else Color(0.55, 0.55, 0.55, 0.75)
	panel.add_theme_stylebox_override(
		"panel",
		_create_panel_style(
			bool(display.active),
			bool(display.available),
			bool(display.equipped)
		)
	)


func _apply_weapon_set_display(result: Dictionary, weapon_set: int) -> void:
	var main_hand := _equipment.get_equipped_item(
		ItemData.EquipSlot.MAIN_HAND, 0, weapon_set
	)
	var off_hand := _equipment.get_equipped_item(
		ItemData.EquipSlot.OFF_HAND, 0, weapon_set
	)
	result.title = "Set %d" % (weapon_set + 1)
	result.equipped = weapon_set == _equipment.get_active_weapon_set()
	var names := PackedStringArray()
	if main_hand != null:
		names.append(main_hand.display_name)
		result.icon = main_hand.get_display_icon()
	if off_hand != null:
		names.append(off_hand.display_name)
		if main_hand == null:
			result.icon = off_hand.get_display_icon()
	var loadout := " + ".join(names) if not names.is_empty() else "No weapon"
	result.detail = "Active • %s" % loadout if bool(result.equipped) else loadout
	result.available = not names.is_empty()


func _apply_item_display(result: Dictionary, item_id: StringName) -> void:
	var item := _inventory.get_item_data(item_id)
	var quantity := _inventory.get_quantity(item_id)
	result.quantity = "x%d" % quantity
	if item == null:
		result.title = String(item_id).capitalize() if not item_id.is_empty() else "Empty"
		result.detail = "Unavailable" if not item_id.is_empty() else ""
		return
	result.title = item.display_name
	result.icon = item.get_display_icon()
	result.available = quantity > 0
	result.detail = "Ready" if quantity > 0 else "Unavailable"


func _create_panel_style(
	active: bool,
	available: bool,
	equipped: bool
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = (
		Color(0.07, 0.14, 0.16, 0.96)
		if equipped
		else Color(0.07, 0.08, 0.11, 0.94)
	)
	style.border_width_left = 2 if active else 1
	style.border_width_top = 2 if active else 1
	style.border_width_right = 2 if active else 1
	style.border_width_bottom = 2 if active else 1
	if active:
		style.border_color = Color(0.96, 0.72, 0.22, 1.0)
	elif equipped:
		style.border_color = Color(0.24, 0.75, 0.82, 0.95)
	elif available:
		style.border_color = Color(0.42, 0.47, 0.58, 0.9)
	else:
		style.border_color = Color(0.25, 0.27, 0.32, 0.75)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_right = 5
	style.corner_radius_bottom_left = 5
	return style


func _on_quick_access_changed(_previous: int, _current: int) -> void:
	refresh()


func _on_slot_assignment_changed(_slot_index: int, _item_id: StringName) -> void:
	refresh()


func _on_inventory_changed() -> void:
	refresh()


func _on_weapon_set_changed(_previous: int, _current: int) -> void:
	refresh()


func _on_loadout_item_changed(
	_equip_slot: ItemData.EquipSlot,
	_slot_index: int,
	_weapon_set: int,
	_previous_item_id: StringName,
	_current_item_id: StringName
) -> void:
	refresh()


func should_disable_on_actor_death() -> bool:
	return false
