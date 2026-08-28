extends Component
class_name QuickAccessComponent

signal active_slot_changed(previous_index: int, current_index: int)
signal slot_assignment_changed(slot_index: int, item_id: StringName)

const QUICK_ACCESS_PROCESS_PRIORITY := -95
const FIRST_CONFIGURABLE_SLOT := 3

@export var config: QuickAccessConfig

var _input: InputComponent
var _inventory: InventoryComponent
var _equipment: EquipmentComponent
var _slots: Array[QuickAccessSlot] = []
var _active_slot: int = 0


func on_initialize() -> void:
	if config == null or config.slot_count != 8:
		push_error("QuickAccessComponent requires an eight-slot config")
		disable()
		return

	_input = actor.get_component(InputComponent) as InputComponent
	_inventory = actor.get_component(InventoryComponent) as InventoryComponent
	_equipment = actor.get_component(EquipmentComponent) as EquipmentComponent
	if _input == null or _inventory == null or _equipment == null:
		push_error("QuickAccessComponent requires input, inventory, and equipment")
		disable()
		return

	_create_default_slots()


func _ready() -> void:
	process_priority = QUICK_ACCESS_PROCESS_PRIORITY


func _process(_delta: float) -> void:
	var requested_slot := _input.consume_equipment_slot_request()
	if requested_slot >= 0 and requested_slot < _slots.size():
		activate_slot(requested_slot)


func activate_slot(slot_index: int) -> bool:
	if not is_enabled or slot_index < 0 or slot_index >= _slots.size():
		return false

	var slot := _slots[slot_index]
	var activated := false
	match slot.kind:
		QuickAccessSlot.Kind.WEAPON_SET:
			activated = _activate_weapon_set(slot.weapon_set)
		QuickAccessSlot.Kind.ITEM:
			activated = _activate_item(slot.item_id)
		QuickAccessSlot.Kind.EMPTY:
			activated = false

	if not activated:
		return false

	var previous := _active_slot
	_active_slot = slot_index
	if previous != _active_slot:
		active_slot_changed.emit(previous, _active_slot)
	return true


func assign_item(slot_index: int, item_id: StringName) -> bool:
	if (
		not is_enabled
		or slot_index < FIRST_CONFIGURABLE_SLOT
		or slot_index >= _slots.size()
	):
		return false

	var item := _inventory.get_item_data(item_id)
	if item == null or not item.usable_in_combat:
		return false

	for index in range(FIRST_CONFIGURABLE_SLOT, _slots.size()):
		if index != slot_index and _slots[index].item_id == item_id:
			return false

	_slots[slot_index] = QuickAccessSlot.item_slot(item_id)
	slot_assignment_changed.emit(slot_index, item_id)
	return true


func clear_slot(slot_index: int) -> bool:
	if slot_index < FIRST_CONFIGURABLE_SLOT or slot_index >= _slots.size():
		return false
	if _slots[slot_index].kind == QuickAccessSlot.Kind.EMPTY:
		return false

	_slots[slot_index] = QuickAccessSlot.new()
	slot_assignment_changed.emit(slot_index, &"")
	if _active_slot == slot_index:
		activate_slot(0)
	return true


func swap_slots(first_index: int, second_index: int) -> bool:
	if (
		not is_enabled
		or first_index < FIRST_CONFIGURABLE_SLOT
		or second_index < FIRST_CONFIGURABLE_SLOT
		or first_index >= _slots.size()
		or second_index >= _slots.size()
		or first_index == second_index
	):
		return false

	var first := _slots[first_index]
	_slots[first_index] = _slots[second_index]
	_slots[second_index] = first
	slot_assignment_changed.emit(first_index, _slots[first_index].item_id)
	slot_assignment_changed.emit(second_index, _slots[second_index].item_id)
	if _active_slot == first_index:
		var previous := _active_slot
		_active_slot = second_index
		active_slot_changed.emit(previous, _active_slot)
	elif _active_slot == second_index:
		var previous := _active_slot
		_active_slot = first_index
		active_slot_changed.emit(previous, _active_slot)
	return true


func get_active_slot() -> int:
	return _active_slot


func get_slot(slot_index: int) -> QuickAccessSlot:
	if slot_index < 0 or slot_index >= _slots.size():
		return null
	return _slots[slot_index].duplicate_slot()


func get_active_item_id() -> StringName:
	var slot := _slots[_active_slot]
	return slot.item_id if slot.kind == QuickAccessSlot.Kind.ITEM else &""


func get_active_item_quantity() -> int:
	var item_id := get_active_item_id()
	return _inventory.get_quantity(item_id) if not item_id.is_empty() else 0


func capture_runtime_state() -> Variant:
	var assignments: Array[StringName] = []
	for slot: QuickAccessSlot in _slots:
		assignments.append(slot.item_id)
	return {
		"active_slot": _active_slot,
		"assignments": assignments,
	}


func restore_runtime_state(state: Variant) -> void:
	if not state is Dictionary:
		return

	_create_default_slots()
	var assignments: Variant = state.get("assignments", [])
	if assignments is Array:
		for index in range(FIRST_CONFIGURABLE_SLOT, mini(assignments.size(), _slots.size())):
			var item_id := StringName(assignments[index])
			if not item_id.is_empty() and _inventory.has_item(item_id):
				assign_item(index, item_id)

	activate_slot(clampi(int(state.get("active_slot", 0)), 0, _slots.size() - 1))


func get_runtime_state_restore_priority() -> int:
	return 100


func _create_default_slots() -> void:
	_slots.clear()
	_slots.resize(config.slot_count)
	for index in _slots.size():
		_slots[index] = QuickAccessSlot.new()
	_slots[0] = QuickAccessSlot.weapon_set_slot(0)
	_slots[1] = QuickAccessSlot.weapon_set_slot(1)
	_slots[2] = QuickAccessSlot.item_slot(config.health_item_id)


func _activate_weapon_set(set_index: int) -> bool:
	if set_index < 0 or set_index >= EquipmentComponent.WEAPON_SET_COUNT:
		return false
	_equipment.switch_weapon_set(set_index)
	var main_hand := _equipment.get_equipped_item(
		ItemData.EquipSlot.MAIN_HAND, 0, set_index
	)
	var action_slot := _equipment.get_item_action_slot(main_hand)
	return _equipment.equip(action_slot) or (
		_equipment.get_current_slot() == action_slot
	)


func _activate_item(item_id: StringName) -> bool:
	if item_id == config.health_item_id:
		return _equipment.equip(EquipmentComponent.Slot.ITEM) or (
			_equipment.get_current_slot() == EquipmentComponent.Slot.ITEM
		)

	var item := _inventory.get_item_data(item_id)
	if item == null or not item.usable_in_combat:
		return false
	var action_slot := _equipment.get_item_action_slot(item)
	return _equipment.equip(action_slot) or (
		_equipment.get_current_slot() == action_slot
	)
