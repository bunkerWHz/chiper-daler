extends Component
class_name QuickAccessHUDComponent

const SLOT_COUNT := 8
const ICON_SIZE := Vector2(64.0, 64.0)
const SLOT_SIZE := Vector2(68.0, 68.0)

var _quick_access: QuickAccessComponent
var _inventory: InventoryComponent
var _inventory_menu: InventoryMenuComponent
var _flask_charges: FlaskChargesComponent
var _slot_views: Array[InventoryDragButton] = []
var _key_labels: Array[Label] = []
var _quantity_labels: Array[Label] = []
var _icons: Array[TextureRect] = []
var _slots_container: HBoxContainer
var _inventory_open := false


func on_initialize() -> void:
	_quick_access = actor.get_component(QuickAccessComponent) as QuickAccessComponent
	_inventory = actor.get_component(InventoryComponent) as InventoryComponent
	_inventory_menu = (
		actor.get_component(InventoryMenuComponent) as InventoryMenuComponent
	)
	_flask_charges = (
		actor.get_component(FlaskChargesComponent) as FlaskChargesComponent
	)
	if _quick_access == null or _inventory == null:
		push_error("QuickAccessHUDComponent requires quick access and inventory")
		disable()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
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
		"ready": false,
		"active": slot_index == _quick_access.get_active_slot(),
	}
	var slot := _quick_access.get_slot(slot_index)
	if slot == null:
		return result

	match slot.kind:
		QuickAccessSlot.Kind.ITEM:
			_apply_item_display(result, slot.item_id)
		QuickAccessSlot.Kind.EMPTY:
			pass
	return result


func get_slot_view(slot_index: int) -> InventoryDragButton:
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
		var panel := InventoryDragButton.new()
		panel.name = "Slot%d" % (slot_index + 1)
		panel.custom_minimum_size = SLOT_SIZE
		panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		panel.focus_mode = Control.FOCUS_NONE
		panel.data_dropped.connect(_on_slot_data_dropped.bind(slot_index))
		panel.drag_finished.connect(_on_slot_drag_finished.bind(slot_index))
		panel.mouse_entered.connect(_on_slot_hovered.bind(slot_index))
		panel.mouse_exited.connect(_on_slot_hover_ended)

		var content := Control.new()
		content.custom_minimum_size = ICON_SIZE
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.offset_left = 2.0
		content.offset_top = 2.0
		content.offset_right = -2.0
		content.offset_bottom = -2.0
		panel.add_child(content)

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
	if (
		_flask_charges != null
		and not _flask_charges.charges_changed.is_connected(
			_on_flask_charges_changed
		)
	):
		_flask_charges.charges_changed.connect(_on_flask_charges_changed)
	if _inventory_menu != null:
		_inventory_open = _inventory_menu.is_open()
		_inventory_menu.open_state_changed.connect(_on_inventory_open_changed)


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
	panel.visible = _inventory_open or bool(display.available)
	panel.modulate = Color.WHITE if bool(display.ready) else Color(0.55, 0.55, 0.55, 0.75)
	var configurable := (
		slot_index >= QuickAccessComponent.FIRST_CONFIGURABLE_SLOT
	)
	panel.drop_target = (
		InventoryDragButton.TARGET_QUICK_SLOT
		if _inventory_open and configurable
		else InventoryDragButton.TARGET_NONE
	)
	panel.drag_payload = {}
	var slot := _quick_access.get_slot(slot_index)
	if (
		_inventory_open
		and configurable
		and slot != null
		and slot.kind == QuickAccessSlot.Kind.ITEM
	):
		var item := _inventory.get_item_data(slot.item_id)
		panel.drag_payload = {
			"kind": InventoryDragButton.KIND_QUICK_SLOT,
			"slot_index": slot_index,
			"item_id": slot.item_id,
			"display_name": (
				item.display_name
				if item != null
				else String(slot.item_id).capitalize()
			),
		}
	panel.add_theme_stylebox_override(
		"normal",
		_create_panel_style(
			bool(display.active),
			bool(display.ready)
		)
	)


func _apply_item_display(result: Dictionary, item_id: StringName) -> void:
	var item := _inventory.get_item_data(item_id)
	var quantity := _inventory.get_quantity(item_id)
	if item == null:
		result.quantity = "x0"
		result.title = String(item_id).capitalize() if not item_id.is_empty() else "Empty"
		result.detail = "Unavailable" if not item_id.is_empty() else ""
		return
	if item.is_flask():
		quantity = (
			_flask_charges.get_charges(item_id)
			if _flask_charges != null
			else 0
		)
	result.quantity = "x%d" % quantity
	result.title = item.display_name
	result.icon = item.get_display_icon()
	result.available = _inventory.has_item(item_id)
	result.ready = quantity > 0
	result.detail = "Ready" if quantity > 0 else "Empty"


func _create_panel_style(
	active: bool,
	available: bool
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.11, 0.94)
	style.border_width_left = 2 if active else 1
	style.border_width_top = 2 if active else 1
	style.border_width_right = 2 if active else 1
	style.border_width_bottom = 2 if active else 1
	if active:
		style.border_color = Color(0.96, 0.72, 0.22, 1.0)
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


func _on_inventory_open_changed(value: bool) -> void:
	_inventory_open = value
	refresh()


func _on_slot_hovered(slot_index: int) -> void:
	if _inventory_open and _inventory_menu != null:
		_inventory_menu.show_quick_slot_details(slot_index)


func _on_slot_hover_ended() -> void:
	if _inventory_menu != null:
		_inventory_menu.hide_hover_details()


func _on_slot_data_dropped(data: Dictionary, slot_index: int) -> void:
	if not _inventory_open:
		return
	var kind := StringName(data.get("kind", &""))
	if kind == InventoryDragButton.KIND_INVENTORY_ITEM:
		_quick_access.assign_item(
			slot_index, StringName(data.get("item_id", &""))
		)
	elif kind == InventoryDragButton.KIND_QUICK_SLOT:
		_quick_access.swap_slots(
			int(data.get("slot_index", -1)), slot_index
		)
	refresh()


func _on_slot_drag_finished(
	successful: bool,
	pointer_position: Vector2,
	slot_index: int
) -> void:
	if (
		successful
		or not _inventory_open
		or slot_index < QuickAccessComponent.FIRST_CONFIGURABLE_SLOT
		or _slots_container.get_global_rect().has_point(pointer_position)
	):
		return
	_quick_access.clear_slot(slot_index)
	refresh()


func _on_inventory_changed() -> void:
	refresh()


func _on_flask_charges_changed(
	_item_id: StringName,
	_current: int,
	_maximum: int
) -> void:
	refresh()


func should_disable_on_actor_death() -> bool:
	return false
