extends Component
class_name InventoryMenuComponent

const MENU_PROCESS_PRIORITY := -80

var _input: InputComponent
var _inventory: InventoryComponent
var _equipment: EquipmentComponent
var _quick_access: QuickAccessComponent
var _inventory_drop: InventoryDropComponent
var _overlay: Control
var _grid: GridContainer
var _equipment_text: Label
var _details_text: Label
var _equip_button: Button
var _drop_button: Button
var _quick_buttons: HBoxContainer
var _selected_item_id: StringName


func on_initialize() -> void:
	_input = actor.get_component(InputComponent) as InputComponent
	_inventory = actor.get_component(InventoryComponent) as InventoryComponent
	_equipment = actor.get_component(EquipmentComponent) as EquipmentComponent
	_quick_access = actor.get_component(QuickAccessComponent) as QuickAccessComponent
	_inventory_drop = (
		actor.get_component(InventoryDropComponent) as InventoryDropComponent
	)
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
	_quick_buttons = get_node_or_null(
		"CanvasLayer/Overlay/Panel/Main/QuickButtons"
	) as HBoxContainer
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
		or _quick_buttons == null
		or close_button == null
	):
		push_error("InventoryMenuComponent scene hierarchy is invalid")
		disable()
		return

	_overlay.visible = false
	close_button.pressed.connect(close_inventory)
	_equip_button.pressed.connect(_equip_selected_item)
	_drop_button.pressed.connect(_drop_selected_item)
	_inventory.inventory_changed.connect(_on_inventory_changed)
	_equipment.loadout_item_changed.connect(_on_loadout_changed)
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
		_set_quick_buttons_enabled(false)
		return

	_details_text.text = "%s [%s]\n%s\nQty: %d  Weight: %.2f  Sell: %d" % [
		item.display_name,
		ItemData.Category.keys()[item.category].capitalize(),
		item.description,
		_inventory.get_quantity(item.id),
		item.weight,
		item.sell_price,
	]
	_equip_button.disabled = item.equip_slot == ItemData.EquipSlot.NONE
	_drop_button.disabled = item.is_key_item
	_set_quick_buttons_enabled(item.usable_in_combat)


func _equip_selected_item() -> void:
	var item := _inventory.get_item_data(_selected_item_id)
	if item == null or item.equip_slot == ItemData.EquipSlot.NONE:
		return

	var slot_index := 0
	var capacity := _equipment.get_slot_capacity(item.equip_slot)
	for index in capacity:
		if _equipment.get_equipped_item_id(item.equip_slot, index).is_empty():
			slot_index = index
			break
	_equipment.equip_inventory_item(item.id, item.equip_slot, slot_index)
	_rebuild_equipment_text()


func _assign_selected_to_quick_slot(slot_index: int) -> void:
	if _quick_access.assign_item(slot_index, _selected_item_id):
		_rebuild_details()


func _drop_selected_item() -> void:
	if _inventory_drop.drop_item(_selected_item_id, 1) != null:
		_rebuild()


func _create_quick_buttons() -> void:
	for child: Node in _quick_buttons.get_children():
		child.free()
	for slot_index in range(QuickAccessComponent.FIRST_CONFIGURABLE_SLOT, 8):
		var button := Button.new()
		button.text = "Assign %d" % (slot_index + 1)
		button.pressed.connect(_assign_selected_to_quick_slot.bind(slot_index))
		_quick_buttons.add_child(button)


func _set_quick_buttons_enabled(value: bool) -> void:
	for button: Button in _quick_buttons.get_children():
		button.disabled = not value


func _rebuild_equipment_text() -> void:
	var lines := PackedStringArray()
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
		_rebuild_equipment_text()
