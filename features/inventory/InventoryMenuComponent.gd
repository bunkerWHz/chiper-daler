extends Component
class_name InventoryMenuComponent

const MENU_PROCESS_PRIORITY := -80

var _input: InputComponent
var _inventory: InventoryComponent
var _equipment: EquipmentComponent
var _quick_access: QuickAccessComponent
var _inventory_drop: InventoryDropComponent
var _attributes: CharacterAttributesComponent
var _item_use: ItemUseComponent
var _overlay: Control
var _grid: GridContainer
var _equipment_text: Label
var _details_text: Label
var _equip_button: Button
var _drop_button: Button
var _use_button: Button
var _split_button: Button
var _quick_buttons: HBoxContainer
var _drop_dialog: ConfirmationDialog
var _drop_quantity: SpinBox
var _selected_item_id: StringName


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
	_overlay = get_node_or_null("CanvasLayer/Overlay") as Control
	_grid = get_node_or_null(
		"CanvasLayer/Overlay/Panel/Main/Content/Inventory/Scroll/Grid"
	) as GridContainer
	_equipment_text = get_node_or_null(
		"CanvasLayer/Overlay/Panel/Main/Content/Equipment/EquipmentText"
	) as Label
	_details_text = get_node_or_null(
		"CanvasLayer/Overlay/Panel/Main/Details"
	) as Label
	_equip_button = get_node_or_null(
		"CanvasLayer/Overlay/Panel/Main/Actions/Equip"
	) as Button
	_drop_button = get_node_or_null(
		"CanvasLayer/Overlay/Panel/Main/Actions/Drop"
	) as Button
	_use_button = get_node_or_null(
		"CanvasLayer/Overlay/Panel/Main/Actions/Use"
	) as Button
	_split_button = get_node_or_null(
		"CanvasLayer/Overlay/Panel/Main/Actions/Split"
	) as Button
	_quick_buttons = get_node_or_null(
		"CanvasLayer/Overlay/Panel/Main/QuickButtons"
	) as HBoxContainer
	_drop_dialog = get_node_or_null("CanvasLayer/DropDialog") as ConfirmationDialog
	_drop_quantity = get_node_or_null(
		"CanvasLayer/DropDialog/Content/Quantity"
	) as SpinBox
	var close_button := get_node_or_null(
		"CanvasLayer/Overlay/Panel/Main/Header/Close"
	) as Button
	if (
		_overlay == null
		or _grid == null
		or _equipment_text == null
		or _details_text == null
		or _equip_button == null
		or _drop_button == null
		or _use_button == null
		or _split_button == null
		or _quick_buttons == null
		or _drop_dialog == null
		or _drop_quantity == null
		or close_button == null
	):
		push_error("InventoryMenuComponent scene hierarchy is invalid")
		disable()
		return

	_overlay.visible = false
	close_button.pressed.connect(close_inventory)
	_equip_button.pressed.connect(_equip_selected_item)
	_drop_button.pressed.connect(_request_drop_selected_item)
	_use_button.pressed.connect(_use_selected_item)
	_split_button.pressed.connect(_split_selected_stack)
	_drop_dialog.confirmed.connect(_confirm_drop_selected_item)
	_inventory.inventory_changed.connect(_on_inventory_changed)
	_equipment.loadout_item_changed.connect(_on_loadout_changed)
	if _attributes != null:
		_attributes.attributes_changed.connect(_on_attributes_changed)
	_create_quick_buttons()


func _process(_delta: float) -> void:
	if _input.consume_inventory_pressed():
		if is_open():
			close_inventory()
		else:
			open_inventory()


func open_inventory() -> void:
	if not is_enabled or _overlay == null:
		return
	_overlay.visible = true
	_rebuild()
	if is_inside_tree():
		get_tree().paused = true


func close_inventory() -> void:
	if _drop_dialog != null:
		_drop_dialog.hide()
	if _overlay != null:
		_overlay.visible = false
	if is_inside_tree():
		get_tree().paused = false


func is_open() -> bool:
	return _overlay != null and _overlay.visible


func disable() -> void:
	close_inventory()
	super.disable()


func _rebuild() -> void:
	_rebuild_grid()
	_rebuild_equipment_text()
	_rebuild_details()


func _rebuild_grid() -> void:
	for child: Node in _grid.get_children():
		child.free()

	for stack: InventoryStack in _inventory.get_stacks():
		var button := Button.new()
		button.custom_minimum_size = Vector2(130.0, 58.0)
		button.text = "%s\nx%d" % [stack.item.display_name, stack.quantity]
		button.tooltip_text = stack.item.description
		button.pressed.connect(_select_item.bind(stack.item.id))
		_grid.add_child(button)


func _select_item(item_id: StringName) -> void:
	_selected_item_id = item_id
	_rebuild_details()


func _rebuild_details() -> void:
	var item := _inventory.get_item_data(_selected_item_id)
	if item == null:
		_details_text.text = "Select an item"
		_equip_button.disabled = true
		_drop_button.disabled = true
		_use_button.disabled = true
		_split_button.disabled = true
		_set_quick_buttons_enabled(false)
		return

	var detail_lines := PackedStringArray()
	detail_lines.append("%s [%s]" % [
		item.display_name,
		ItemData.Category.keys()[item.category].capitalize(),
	])
	detail_lines.append(item.description)
	detail_lines.append("Qty: %d  Weight: %.2f  Sell: %d" % [
		_inventory.get_quantity(item.id),
		item.weight,
		item.sell_price,
	])
	_append_item_stats(detail_lines, item)
	_details_text.text = "\n".join(detail_lines)
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
	_set_quick_buttons_enabled(item.usable_in_combat)


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
	_rebuild_equipment_text()


func _toggle_selected_quick_slot(slot_index: int) -> void:
	var slot := _quick_access.get_slot(slot_index)
	if slot != null and slot.item_id == _selected_item_id:
		if _quick_access.clear_slot(slot_index):
			_rebuild_details()
	elif _quick_access.assign_item(slot_index, _selected_item_id):
		_rebuild_details()


func _assign_selected_to_quick_slot(slot_index: int) -> void:
	_toggle_selected_quick_slot(slot_index)


func _drop_selected_item() -> void:
	if _inventory_drop.drop_item(_selected_item_id, 1) != null:
		_rebuild()


func _request_drop_selected_item() -> void:
	var quantity := _inventory.get_quantity(_selected_item_id)
	if quantity <= 0:
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


func _create_quick_buttons() -> void:
	for child: Node in _quick_buttons.get_children():
		child.free()
	for slot_index in range(QuickAccessComponent.FIRST_CONFIGURABLE_SLOT, 8):
		var button := Button.new()
		button.text = "Assign %d" % (slot_index + 1)
		button.pressed.connect(_toggle_selected_quick_slot.bind(slot_index))
		_quick_buttons.add_child(button)


func _set_quick_buttons_enabled(value: bool) -> void:
	var slot_index := QuickAccessComponent.FIRST_CONFIGURABLE_SLOT
	for button: Button in _quick_buttons.get_children():
		var slot := _quick_access.get_slot(slot_index)
		button.text = (
			"Clear %d" % (slot_index + 1)
			if slot != null and slot.item_id == _selected_item_id
			else "Assign %d" % (slot_index + 1)
		)
		button.disabled = not value
		slot_index += 1


func _rebuild_equipment_text() -> void:
	var lines := PackedStringArray()
	var attributes := (
		actor.get_component(CharacterAttributesComponent)
		as CharacterAttributesComponent
	)
	if attributes != null:
		lines.append("STR: %d  DEX: %d" % [
			attributes.strength,
			attributes.dexterity,
		])
	lines.append("Total Defense: %.1f" % _equipment.get_total_defense())
	for set_index in EquipmentComponent.WEAPON_SET_COUNT:
		lines.append("Weapon Set %d%s" % [
			set_index + 1,
			" (active)" if set_index == _equipment.get_active_weapon_set() else "",
		])
		lines.append("  Main: %s" % _equipped_name(
			ItemData.EquipSlot.MAIN_HAND, 0, set_index
		))
		lines.append("  Off: %s" % _equipped_name(
			ItemData.EquipSlot.OFF_HAND, 0, set_index
		))

	for slot: ItemData.EquipSlot in [
		ItemData.EquipSlot.HEAD,
		ItemData.EquipSlot.CHEST,
		ItemData.EquipSlot.HANDS,
		ItemData.EquipSlot.LEGS,
		ItemData.EquipSlot.AMULET,
		ItemData.EquipSlot.BACK,
	]:
		lines.append("%s: %s" % [
			ItemData.EquipSlot.keys()[slot].capitalize(),
			_equipped_name(slot),
		])
	for index in 2:
		lines.append("Ring %d: %s" % [
			index + 1,
			_equipped_name(ItemData.EquipSlot.RING, index),
		])
		lines.append("Earring %d: %s" % [
			index + 1,
			_equipped_name(ItemData.EquipSlot.EARRING, index),
		])
	_equipment_text.text = "\n".join(lines)


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


func _equipped_name(
	slot: ItemData.EquipSlot,
	index: int = 0,
	weapon_set: int = -1
) -> String:
	var item := _equipment.get_equipped_item(slot, index, weapon_set)
	return item.display_name if item != null else "—"


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
