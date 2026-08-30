extends Component
class_name InventoryMenuComponent

signal open_state_changed(is_open: bool)

const MENU_PROCESS_PRIORITY := -80
const ALL_CATEGORIES := -1

enum SortMode {
	NAME,
	CATEGORY,
	WEIGHT,
	VALUE,
}

var _input: InputComponent
var _inventory: InventoryComponent
var _equipment: EquipmentComponent
var _quick_access: QuickAccessComponent
var _inventory_drop: InventoryDropComponent
var _attributes: CharacterAttributesComponent
var _item_use: ItemUseComponent
var _panel: Control
var _grid: GridContainer
var _equipment_text: Label
var _detail_popup: PanelContainer
var _details_text: Label
var _equip_button: Button
var _drop_button: Button
var _use_button: Button
var _split_button: Button
var _drop_dialog: ConfirmationDialog
var _drop_quantity: SpinBox
var _equipment_slots: GridContainer
var _weapon_set_buttons: HBoxContainer
var _category_filter: OptionButton
var _sort_option: OptionButton
var _inventory_summary: Label
var _selected_item_id: StringName
var _selected_category: int = ALL_CATEGORIES
var _sort_mode: SortMode = SortMode.NAME
var _details_pinned := false
var _pinned_detail_position := Vector2.ZERO


func on_initialize() -> void:
	_input = actor.get_component(InputComponent) as InputComponent
	_inventory = actor.get_component(InventoryComponent) as InventoryComponent
	_equipment = actor.get_component(EquipmentComponent) as EquipmentComponent
	_quick_access = actor.get_component(QuickAccessComponent) as QuickAccessComponent
	_inventory_drop = (
		actor.get_component(InventoryDropComponent) as InventoryDropComponent
	)
	_attributes = (
		actor.get_component(CharacterAttributesComponent)
		as CharacterAttributesComponent
	)
	_item_use = actor.get_component(ItemUseComponent) as ItemUseComponent
	if (
		_input == null
		or _inventory == null
		or _equipment == null
		or _quick_access == null
		or _inventory_drop == null
	):
		push_error(
			"InventoryMenuComponent requires inventory, equipment, quick access, and drop"
		)
		disable()


func _ready() -> void:
	process_priority = MENU_PROCESS_PRIORITY
	if not is_enabled:
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = get_node_or_null("CanvasLayer/Panel") as Control
	_grid = get_node_or_null(
		"CanvasLayer/Panel/Main/Content/Inventory/Scroll/Grid"
	) as GridContainer
	_equipment_text = get_node_or_null(
		"CanvasLayer/Panel/Main/Content/Equipment/EquipmentText"
	) as Label
	_detail_popup = get_node_or_null(
		"CanvasLayer/DetailPopup"
	) as PanelContainer
	_details_text = get_node_or_null(
		"CanvasLayer/DetailPopup/Margin/Details"
	) as Label
	_equip_button = get_node_or_null(
		"CanvasLayer/Panel/Main/Actions/Equip"
	) as Button
	_drop_button = get_node_or_null(
		"CanvasLayer/Panel/Main/Actions/Drop"
	) as Button
	_use_button = get_node_or_null(
		"CanvasLayer/Panel/Main/Actions/Use"
	) as Button
	_split_button = get_node_or_null(
		"CanvasLayer/Panel/Main/Actions/Split"
	) as Button
	_drop_dialog = get_node_or_null("CanvasLayer/DropDialog") as ConfirmationDialog
	_drop_quantity = get_node_or_null(
		"CanvasLayer/DropDialog/Content/Quantity"
	) as SpinBox
	_equipment_slots = get_node_or_null(
		"CanvasLayer/Panel/Main/Content/Equipment/EquipmentScroll/EquipmentSlots"
	) as GridContainer
	_weapon_set_buttons = get_node_or_null(
		"CanvasLayer/Panel/Main/Content/Equipment/WeaponSets"
	) as HBoxContainer
	_category_filter = get_node_or_null(
		"CanvasLayer/Panel/Main/Content/Inventory/Toolbar/Category"
	) as OptionButton
	_sort_option = get_node_or_null(
		"CanvasLayer/Panel/Main/Content/Inventory/Toolbar/Sort"
	) as OptionButton
	_inventory_summary = get_node_or_null(
		"CanvasLayer/Panel/Main/Content/Inventory/Summary"
	) as Label
	var close_button := get_node_or_null(
		"CanvasLayer/Panel/Main/Header/Close"
	) as Button
	if (
		_panel == null
		or _grid == null
		or _equipment_text == null
		or _detail_popup == null
		or _details_text == null
		or _equip_button == null
		or _drop_button == null
		or _use_button == null
		or _split_button == null
		or _drop_dialog == null
		or _drop_quantity == null
		or _equipment_slots == null
		or _weapon_set_buttons == null
		or _category_filter == null
		or _sort_option == null
		or _inventory_summary == null
		or close_button == null
	):
		push_error("InventoryMenuComponent scene hierarchy is invalid")
		disable()
		return

	_panel.visible = false
	close_button.pressed.connect(close_inventory)
	_equip_button.pressed.connect(_equip_selected_item)
	_drop_button.pressed.connect(_request_drop_selected_item)
	_use_button.pressed.connect(_use_selected_item)
	_split_button.pressed.connect(_split_selected_stack)
	_drop_dialog.confirmed.connect(_confirm_drop_selected_item)
	_inventory.inventory_changed.connect(_on_inventory_changed)
	_equipment.loadout_item_changed.connect(_on_loadout_changed)
	_equipment.weapon_set_changed.connect(_on_weapon_set_changed)
	if _attributes != null:
		_attributes.attributes_changed.connect(_on_attributes_changed)
	_setup_toolbar()
	_create_weapon_set_buttons()


func _process(_delta: float) -> void:
	if _input.consume_inventory_pressed():
		if is_open():
			close_inventory()
		else:
			open_inventory()


func open_inventory() -> void:
	if not is_enabled or _panel == null:
		return
	_panel.visible = true
	_details_pinned = false
	_detail_popup.visible = false
	_rebuild()
	open_state_changed.emit(true)
	if is_inside_tree():
		get_tree().paused = true


func close_inventory() -> void:
	var was_open := is_open()
	if _drop_dialog != null:
		_drop_dialog.hide()
	if _panel != null:
		_panel.visible = false
	_details_pinned = false
	if _detail_popup != null:
		_detail_popup.visible = false
	if was_open:
		open_state_changed.emit(false)
	if is_inside_tree():
		get_tree().paused = false


func is_open() -> bool:
	return _panel != null and _panel.visible


func disable() -> void:
	close_inventory()
	super.disable()


func _rebuild() -> void:
	_rebuild_grid()
	_rebuild_equipment_text()
	_rebuild_equipment_slots()
	_rebuild_inventory_summary()
	_rebuild_details()


func _rebuild_grid() -> void:
	_clear_dynamic_children(_grid)

	var stacks := _get_visible_stacks()
	for stack: InventoryStack in stacks:
		var button := InventoryDragButton.new()
		button.custom_minimum_size = Vector2(72.0, 72.0)
		button.text = ""
		button.icon = stack.item.get_display_icon()
		button.add_theme_constant_override("icon_max_width", 64)
		button.expand_icon = true
		button.tooltip_text = stack.item.display_name
		if stack.item.id == _selected_item_id:
			button.add_theme_stylebox_override("normal", _selected_item_style())
		button.drag_payload = _inventory_item_payload(stack.item)
		button.drop_target = InventoryDragButton.TARGET_INVENTORY
		button.data_dropped.connect(_on_inventory_data_dropped)
		button.pressed.connect(_select_item.bind(stack.item.id))
		button.mouse_entered.connect(show_item_details.bind(stack.item.id))
		button.mouse_exited.connect(hide_hover_details)
		button.focus_entered.connect(show_item_details.bind(stack.item.id))
		button.focus_exited.connect(hide_hover_details)
		_grid.add_child(button)

	if _selected_category == ALL_CATEGORIES:
		for _empty_index in _inventory.get_capacity() - stacks.size():
			var empty_cell := InventoryDragButton.new()
			empty_cell.custom_minimum_size = Vector2(72.0, 72.0)
			empty_cell.text = ""
			empty_cell.icon = ItemData.PLACEHOLDER_ICON
			empty_cell.add_theme_constant_override("icon_max_width", 64)
			empty_cell.expand_icon = true
			empty_cell.modulate = Color(0.45, 0.45, 0.45, 0.55)
			empty_cell.focus_mode = Control.FOCUS_NONE
			empty_cell.drop_target = InventoryDragButton.TARGET_INVENTORY
			empty_cell.data_dropped.connect(_on_inventory_data_dropped)
			_grid.add_child(empty_cell)


func _select_item(item_id: StringName) -> void:
	_selected_item_id = item_id
	_details_pinned = true
	_rebuild_grid()
	_rebuild_details()


func _rebuild_details() -> void:
	var item := _inventory.get_item_data(_selected_item_id)
	if item == null:
		_details_pinned = false
		_detail_popup.visible = false
		_equip_button.disabled = true
		_drop_button.disabled = true
		_use_button.disabled = true
		_split_button.disabled = true
		return

	_details_text.text = _get_item_details(item)
	if _details_pinned:
		_detail_popup.visible = true
		_position_detail_popup()
		_pinned_detail_position = _detail_popup.position
	var equipped := _equipment.is_item_equipped(item.id)
	_equip_button.text = "Unequip" if equipped else "Equip"
	_equip_button.disabled = (
		item.equip_slot == ItemData.EquipSlot.NONE
		or (not equipped and not _equipment.meets_item_requirements(item))
	)
	_drop_button.disabled = item.is_key_item
	_use_button.disabled = (
		_item_use == null
		or not _item_use.can_use_inventory_item_now(item.id)
	)
	_split_button.disabled = not _inventory.can_split_stack(item.id)


func show_item_details(item_id: StringName) -> void:
	var item := _inventory.get_item_data(item_id)
	if item == null:
		return
	_show_details_text(_get_item_details(item))


func show_quick_slot_details(slot_index: int) -> void:
	if not is_open():
		return
	var slot := _quick_access.get_slot(slot_index)
	if slot == null:
		return
	match slot.kind:
		QuickAccessSlot.Kind.ITEM:
			show_item_details(slot.item_id)
		QuickAccessSlot.Kind.EMPTY:
			_show_details_text(
				"Quick Slot %d\nEmpty\nDrag a combat item here."
				% (slot_index + 1)
			)


func hide_hover_details() -> void:
	if _details_pinned:
		var selected := _inventory.get_item_data(_selected_item_id)
		if selected != null:
			_details_text.text = _get_item_details(selected)
			_detail_popup.position = _pinned_detail_position
			_detail_popup.visible = true
			return
	_detail_popup.visible = false


func _show_details_text(text: String) -> void:
	_details_text.text = text
	_detail_popup.visible = true
	_position_detail_popup()


func _get_item_details(item: ItemData) -> String:
	var detail_lines := PackedStringArray()
	detail_lines.append("%s [%s]" % [
		item.display_name,
		ItemData.Category.keys()[item.category].capitalize(),
	])
	detail_lines.append(item.description)
	var owned_quantity := _inventory.get_quantity(item.id)
	var equipped_quantity := _equipment.get_equipped_item_count(item.id)
	if equipped_quantity > 0:
		detail_lines.append("Bag: %d  Equipped: %d" % [
			maxi(owned_quantity - equipped_quantity, 0),
			equipped_quantity,
		])
	else:
		detail_lines.append("Qty: %d" % owned_quantity)
	detail_lines.append("Weight: %.2f  Sell: %d" % [
		item.weight,
		item.sell_price,
	])
	_append_item_stats(detail_lines, item)
	return "\n".join(detail_lines)


func _position_detail_popup() -> void:
	if not is_inside_tree():
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var popup_size := _detail_popup.size
	var target := get_viewport().get_mouse_position() + Vector2(18.0, 18.0)
	target.x = clampf(
		target.x, 8.0, maxf(8.0, viewport_size.x - popup_size.x - 8.0)
	)
	target.y = clampf(
		target.y, 8.0, maxf(8.0, viewport_size.y - popup_size.y - 8.0)
	)
	_detail_popup.position = target


func _equip_selected_item() -> void:
	var item := _inventory.get_item_data(_selected_item_id)
	if item == null or item.equip_slot == ItemData.EquipSlot.NONE:
		return
	if _equipment.is_item_equipped(item.id):
		_equipment.unequip_inventory_item(item.id)
		_rebuild()
		return

	var slot_index := 0
	var capacity := _equipment.get_slot_capacity(item.equip_slot)
	for index in capacity:
		if _equipment.get_equipped_item_id(item.equip_slot, index).is_empty():
			slot_index = index
			break
	_equipment.equip_inventory_item(item.id, item.equip_slot, slot_index)
	_rebuild()


func _drop_selected_item() -> void:
	if _inventory_drop.drop_item(_selected_item_id, 1) != null:
		_rebuild()


func _request_drop_selected_item() -> void:
	var quantity := _inventory.get_quantity(_selected_item_id)
	if quantity <= 0:
		return
	if quantity == 1:
		_drop_dialog.hide()
		_drop_selected_item()
		return
	_drop_quantity.max_value = quantity
	_drop_quantity.value = 1
	if is_inside_tree():
		_drop_dialog.popup_centered()


func _confirm_drop_selected_item() -> void:
	var quantity := int(_drop_quantity.value)
	if _inventory_drop.drop_item(_selected_item_id, quantity) != null:
		_rebuild()


func _use_selected_item() -> void:
	if _item_use != null and _item_use.use_inventory_item_now(_selected_item_id):
		_rebuild()


func _split_selected_stack() -> void:
	if _inventory.split_stack(_selected_item_id):
		_rebuild()


func _setup_toolbar() -> void:
	_category_filter.clear()
	_category_filter.add_item("All categories")
	for category_name: String in ItemData.Category.keys():
		_category_filter.add_item(category_name.capitalize())
	_category_filter.select(0)
	_category_filter.item_selected.connect(_on_category_selected)

	_sort_option.clear()
	_sort_option.add_item("Name")
	_sort_option.add_item("Category")
	_sort_option.add_item("Weight")
	_sort_option.add_item("Value")
	_sort_option.select(SortMode.NAME)
	_sort_option.item_selected.connect(_on_sort_selected)


func _create_weapon_set_buttons() -> void:
	_clear_dynamic_children(_weapon_set_buttons)
	for set_index in EquipmentComponent.WEAPON_SET_COUNT:
		var button := Button.new()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_activate_weapon_set.bind(set_index))
		_weapon_set_buttons.add_child(button)
	_refresh_weapon_set_buttons()


func _rebuild_equipment_slots() -> void:
	_clear_dynamic_children(_equipment_slots)

	for set_index in EquipmentComponent.WEAPON_SET_COUNT:
		_add_equipment_slot_button(
			"Set %d Main" % (set_index + 1),
			ItemData.EquipSlot.MAIN_HAND,
			0,
			set_index
		)
		_add_equipment_slot_button(
			"Set %d Off" % (set_index + 1),
			ItemData.EquipSlot.OFF_HAND,
			0,
			set_index
		)

	for slot: ItemData.EquipSlot in [
		ItemData.EquipSlot.HEAD,
		ItemData.EquipSlot.CHEST,
		ItemData.EquipSlot.HANDS,
		ItemData.EquipSlot.LEGS,
		ItemData.EquipSlot.AMULET,
		ItemData.EquipSlot.BACK,
	]:
		_add_equipment_slot_button(
			ItemData.EquipSlot.keys()[slot].capitalize(), slot
		)
	for index in 2:
		_add_equipment_slot_button(
			"Ring %d" % (index + 1), ItemData.EquipSlot.RING, index
		)
		_add_equipment_slot_button(
			"Earring %d" % (index + 1), ItemData.EquipSlot.EARRING, index
		)
	_refresh_weapon_set_buttons()


func _clear_dynamic_children(container: Container) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _add_equipment_slot_button(
	label: String,
	slot: ItemData.EquipSlot,
	index: int = 0,
	weapon_set: int = -1
) -> void:
	var item := _equipment.get_equipped_item(slot, index, weapon_set)
	var button := InventoryDragButton.new()
	button.custom_minimum_size = Vector2(72.0, 72.0)
	button.text = ""
	button.icon = item.get_display_icon() if item != null else null
	button.add_theme_constant_override("icon_max_width", 64)
	button.expand_icon = true
	button.tooltip_text = (
		"%s: %s" % [label, item.display_name]
		if item != null
		else "%s: Empty" % label
	)
	button.drop_target = InventoryDragButton.TARGET_EQUIPMENT
	button.target_equip_slot = slot
	button.data_dropped.connect(
		_on_equipment_data_dropped.bind(slot, index, weapon_set)
	)
	if item != null:
		button.drag_payload = {
			"kind": InventoryDragButton.KIND_EQUIPPED_ITEM,
			"item_id": item.id,
			"equip_slot": slot,
			"slot_index": index,
			"weapon_set": weapon_set,
			"display_name": item.display_name,
		}
		button.pressed.connect(
			_select_equipped_slot.bind(slot, index, weapon_set)
		)
		button.mouse_entered.connect(show_item_details.bind(item.id))
		button.mouse_exited.connect(hide_hover_details)
		button.focus_entered.connect(show_item_details.bind(item.id))
		button.focus_exited.connect(hide_hover_details)
	_equipment_slots.add_child(button)


func _select_equipped_slot(
	slot: ItemData.EquipSlot,
	index: int,
	weapon_set: int
) -> void:
	var item_id := _equipment.get_equipped_item_id(slot, index, weapon_set)
	if not item_id.is_empty():
		_select_item(item_id)


func _activate_weapon_set(set_index: int) -> void:
	_equipment.switch_weapon_set(set_index)
	_rebuild()


func _refresh_weapon_set_buttons() -> void:
	var active_set := _equipment.get_active_weapon_set()
	var set_index := 0
	for button: Button in _weapon_set_buttons.get_children():
		button.text = "Weapon Set %d%s" % [
			set_index + 1,
			" • Active" if set_index == active_set else "",
		]
		button.disabled = (
			set_index == active_set
		)
		set_index += 1


func _rebuild_inventory_summary() -> void:
	var visible_stacks := _get_unequipped_stacks()
	var visible_weight := 0.0
	for stack: InventoryStack in visible_stacks:
		visible_weight += stack.item.weight * stack.quantity
	_inventory_summary.text = "Bag slots %d / %d    Weight %.2f" % [
		visible_stacks.size(),
		_inventory.get_capacity(),
		visible_weight,
	]


func _get_visible_stacks() -> Array[InventoryStack]:
	var result: Array[InventoryStack] = []
	for stack: InventoryStack in _get_unequipped_stacks():
		if (
			_selected_category == ALL_CATEGORIES
			or stack.item.category == _selected_category
		):
			result.append(stack)
	result.sort_custom(_is_stack_before)
	return result


func _get_unequipped_stacks() -> Array[InventoryStack]:
	var result: Array[InventoryStack] = []
	var remaining_equipped: Dictionary = {}
	for stack: InventoryStack in _inventory.get_stacks():
		var item_id := stack.item.id
		if not remaining_equipped.has(item_id):
			remaining_equipped[item_id] = (
				_equipment.get_equipped_item_count(item_id)
			)
		var hidden_quantity := mini(
			stack.quantity, int(remaining_equipped[item_id])
		)
		remaining_equipped[item_id] = (
			int(remaining_equipped[item_id]) - hidden_quantity
		)
		var visible_quantity := stack.quantity - hidden_quantity
		if visible_quantity > 0:
			result.append(InventoryStack.new(stack.item, visible_quantity))
	return result


func _is_stack_before(left: InventoryStack, right: InventoryStack) -> bool:
	match _sort_mode:
		SortMode.CATEGORY:
			if left.item.category != right.item.category:
				return left.item.category < right.item.category
		SortMode.WEIGHT:
			if not is_equal_approx(left.item.weight, right.item.weight):
				return left.item.weight < right.item.weight
		SortMode.VALUE:
			if left.item.sell_price != right.item.sell_price:
				return left.item.sell_price > right.item.sell_price
		SortMode.NAME:
			pass
	return left.item.display_name.naturalnocasecmp_to(
		right.item.display_name
	) < 0


func _rarity_color(rarity: ItemData.Rarity) -> Color:
	match rarity:
		ItemData.Rarity.UNCOMMON:
			return Color(0.48, 0.9, 0.5)
		ItemData.Rarity.RARE:
			return Color(0.4, 0.68, 1.0)
		ItemData.Rarity.EPIC:
			return Color(0.75, 0.48, 1.0)
		ItemData.Rarity.LEGENDARY:
			return Color(1.0, 0.68, 0.22)
		_:
			return Color(0.92, 0.94, 1.0)


func _selected_item_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.12, 0.07, 0.95)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.96, 0.72, 0.22, 1.0)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	return style


func _on_category_selected(index: int) -> void:
	_selected_category = index - 1
	_rebuild_grid()


func _on_sort_selected(index: int) -> void:
	_sort_mode = index as SortMode
	_rebuild_grid()


func _inventory_item_payload(item: ItemData) -> Dictionary:
	return {
		"kind": InventoryDragButton.KIND_INVENTORY_ITEM,
		"item_id": item.id,
		"equip_slot": item.equip_slot,
		"usable": item.usable_in_combat,
		"display_name": item.display_name,
	}


func _on_inventory_data_dropped(data: Dictionary) -> void:
	var kind := StringName(data.get("kind", &""))
	if kind == InventoryDragButton.KIND_EQUIPPED_ITEM:
		_equipment.unequip_item(
			int(data.get("equip_slot", ItemData.EquipSlot.NONE)) as ItemData.EquipSlot,
			int(data.get("slot_index", 0)),
			int(data.get("weapon_set", -1))
		)
	elif kind == InventoryDragButton.KIND_QUICK_SLOT:
		_quick_access.clear_slot(int(data.get("slot_index", -1)))
	_rebuild()


func _on_equipment_data_dropped(
	data: Dictionary,
	slot: ItemData.EquipSlot,
	index: int,
	weapon_set: int
) -> void:
	var kind := StringName(data.get("kind", &""))
	if kind == InventoryDragButton.KIND_INVENTORY_ITEM:
		_equipment.equip_inventory_item(
			StringName(data.get("item_id", &"")), slot, index, weapon_set
		)
	elif kind == InventoryDragButton.KIND_EQUIPPED_ITEM:
		_move_equipped_item(data, slot, index, weapon_set)
	_rebuild()


func _move_equipped_item(
	data: Dictionary,
	target_slot: ItemData.EquipSlot,
	target_index: int,
	target_weapon_set: int
) -> void:
	var source_slot := int(
		data.get("equip_slot", ItemData.EquipSlot.NONE)
	) as ItemData.EquipSlot
	var source_index := int(data.get("slot_index", 0))
	var source_weapon_set := int(data.get("weapon_set", -1))
	if (
		source_slot == target_slot
		and source_index == target_index
		and source_weapon_set == target_weapon_set
	):
		return
	var source_item_id := _equipment.get_equipped_item_id(
		source_slot, source_index, source_weapon_set
	)
	if source_item_id.is_empty():
		return
	var displaced_item_id := _equipment.get_equipped_item_id(
		target_slot, target_index, target_weapon_set
	)
	_equipment.unequip_item(target_slot, target_index, target_weapon_set)
	_equipment.unequip_item(source_slot, source_index, source_weapon_set)
	if not _equipment.equip_inventory_item(
		source_item_id, target_slot, target_index, target_weapon_set
	):
		_equipment.equip_inventory_item(
			source_item_id, source_slot, source_index, source_weapon_set
		)
		if not displaced_item_id.is_empty():
			_equipment.equip_inventory_item(
				displaced_item_id,
				target_slot,
				target_index,
				target_weapon_set
			)
		return
	if displaced_item_id.is_empty():
		return
	var displaced_item := _inventory.get_item_data(displaced_item_id)
	if displaced_item != null and displaced_item.can_equip_in(source_slot):
		_equipment.equip_inventory_item(
			displaced_item_id, source_slot, source_index, source_weapon_set
		)


func _rebuild_equipment_text() -> void:
	var attributes := (
		actor.get_component(CharacterAttributesComponent)
		as CharacterAttributesComponent
	)
	var strength := 0
	var dexterity := 0
	if attributes != null:
		strength = attributes.strength
		dexterity = attributes.dexterity
	_equipment_text.text = "STR %d  DEX %d    Defense %.1f" % [
		strength,
		dexterity,
		_equipment.get_total_defense(),
	]


func _append_item_stats(lines: PackedStringArray, item: ItemData) -> void:
	if item.stats == null:
		return
	lines.append("Damage: %.1f  Defense: %.1f" % [
		item.stats.damage,
		item.stats.defense,
	])
	if (
		item.stats.strength_requirement > 0
		or item.stats.dexterity_requirement > 0
	):
		lines.append("Requires STR %d / DEX %d" % [
			item.stats.strength_requirement,
			item.stats.dexterity_requirement,
		])
	var failure := _equipment.get_requirement_failure(item)
	if not failure.is_empty():
		lines.append("Requirements not met: %s" % failure)
	if item.equip_slot == ItemData.EquipSlot.NONE:
		return
	var equipped := _equipment.get_equipped_item(item.equip_slot)
	if equipped == null or equipped.id == item.id or equipped.stats == null:
		return
	lines.append("Compared with %s: Damage %+.1f / Defense %+.1f" % [
		equipped.display_name,
		item.stats.damage - equipped.stats.damage,
		item.stats.defense - equipped.stats.defense,
	])


func _on_inventory_changed() -> void:
	if is_open():
		_rebuild()


func _on_loadout_changed(
	_slot: ItemData.EquipSlot,
	_index: int,
	_weapon_set: int,
	_previous: StringName,
	_current: StringName
) -> void:
	if is_open():
		_rebuild()


func _on_attributes_changed(_strength: int, _dexterity: int) -> void:
	if is_open():
		_rebuild()


func _on_weapon_set_changed(_previous: int, _current: int) -> void:
	if is_open():
		_rebuild()
