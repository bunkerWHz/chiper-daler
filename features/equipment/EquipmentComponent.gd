extends Component
class_name EquipmentComponent

enum Slot {
	MELEE,
	ITEM,
	THROWABLE,
	BOW,
	CROSSBOW,
	MAGIC,
}

signal equipment_changed(previous_slot: Slot, current_slot: Slot)
signal weapon_set_changed(previous_set: int, current_set: int)
signal loadout_item_changed(
	equip_slot: ItemData.EquipSlot,
	slot_index: int,
	weapon_set: int,
	previous_item_id: StringName,
	current_item_id: StringName
)

const EQUIPMENT_PROCESS_PRIORITY := -90
const WEAPON_SET_COUNT := 2

@export var default_slot: Slot = Slot.MELEE
@export var starting_main_hand_ids: Array[StringName] = []
@export var starting_off_hand_ids: Array[StringName] = []

var _input_component: InputComponent
var _inventory_component: InventoryComponent
var _attributes_component: CharacterAttributesComponent
var _current_slot: Slot = Slot.MELEE
var _active_weapon_set: int = 0
var _equipped_items: Dictionary = {}


func on_initialize() -> void:
	_input_component = actor.get_component(InputComponent) as InputComponent
	_inventory_component = (
		actor.get_component(InventoryComponent) as InventoryComponent
	)
	_attributes_component = (
		actor.get_component(CharacterAttributesComponent)
		as CharacterAttributesComponent
	)
	if (
		_attributes_component != null
		and not _attributes_component.attributes_changed.is_connected(
			_on_attributes_changed
		)
	):
		_attributes_component.attributes_changed.connect(_on_attributes_changed)

	if _input_component == null or not _input_component.is_enabled:
		push_error("EquipmentComponent requires an enabled InputComponent")
		disable()
		return

	_current_slot = default_slot
	if _inventory_component != null and _inventory_component.is_enabled:
		if not _inventory_component.inventory_changed.is_connected(
			_on_inventory_changed
		):
			_inventory_component.inventory_changed.connect(
				_on_inventory_changed
			)


func _ready() -> void:
	process_priority = EQUIPMENT_PROCESS_PRIORITY
	_equip_starting_weapon_sets()


func _process(_delta: float) -> void:
	if _input_component.consume_weapon_set_swap_pressed():
		cycle_weapon_set()


func equip(slot: Slot) -> bool:
	if not is_enabled or slot == _current_slot:
		return false

	var previous_slot := _current_slot
	_current_slot = slot
	equipment_changed.emit(previous_slot, _current_slot)
	return true


func get_current_slot() -> Slot:
	return _current_slot


func get_current_slot_name() -> String:
	return Slot.keys()[_current_slot].to_pascal_case()


func is_slot_active(slot: Slot) -> bool:
	return is_enabled and _current_slot == slot


func allows_melee_actions() -> bool:
	if not is_slot_active(Slot.MELEE):
		return false
	if _inventory_component == null:
		return true
	var active_weapon := get_equipped_item(ItemData.EquipSlot.MAIN_HAND)
	return (
		active_weapon != null
		and get_item_action_slot(active_weapon) == Slot.MELEE
	)


func equip_inventory_item(
	item_id: StringName,
	target_slot: ItemData.EquipSlot,
	slot_index: int = 0,
	weapon_set: int = -1
) -> bool:
	if not is_enabled or _inventory_component == null:
		return false

	var item := _inventory_component.get_item_data(item_id)
	if (
		item == null
		or not item.can_equip_in(target_slot)
		or not meets_item_requirements(item)
	):
		return false

	var resolved_set := _resolve_weapon_set(target_slot, weapon_set)
	if resolved_set < -1 or resolved_set >= WEAPON_SET_COUNT:
		return false
	if not _is_valid_slot_index(target_slot, slot_index):
		return false

	var key := _make_equipment_key(target_slot, slot_index, resolved_set)
	var previous := StringName(_equipped_items.get(key, &""))
	if previous == item_id:
		return false
	if _count_equipped_item(item_id) >= _inventory_component.get_quantity(item_id):
		return false

	_equipped_items[key] = item_id
	loadout_item_changed.emit(
		target_slot,
		slot_index,
		resolved_set,
		previous,
		item_id
	)
	if (
		target_slot == ItemData.EquipSlot.MAIN_HAND
		and resolved_set == _active_weapon_set
	):
		equip(get_item_action_slot(item))
	return true


func unequip_item(
	target_slot: ItemData.EquipSlot,
	slot_index: int = 0,
	weapon_set: int = -1
) -> bool:
	var resolved_set := _resolve_weapon_set(target_slot, weapon_set)
	var key := _make_equipment_key(target_slot, slot_index, resolved_set)
	if not _equipped_items.has(key):
		return false

	var previous := StringName(_equipped_items[key])
	_equipped_items.erase(key)
	loadout_item_changed.emit(
		target_slot,
		slot_index,
		resolved_set,
		previous,
		&""
	)
	return true


func is_item_equipped(item_id: StringName) -> bool:
	return not item_id.is_empty() and _equipped_items.values().has(item_id)


func get_equipped_item_count(item_id: StringName) -> int:
	if item_id.is_empty():
		return 0
	return _count_equipped_item(item_id)


func unequip_inventory_item(item_id: StringName) -> bool:
	if item_id.is_empty():
		return false
	for key: Variant in _equipped_items.keys():
		if StringName(_equipped_items[key]) != item_id:
			continue
		var was_active_main := (
			get_equipped_item_id(ItemData.EquipSlot.MAIN_HAND) == item_id
		)
		_remove_equipped_key(key)
		if was_active_main:
			equip(Slot.MELEE)
		return true
	return false


func get_equipped_item_id(
	target_slot: ItemData.EquipSlot,
	slot_index: int = 0,
	weapon_set: int = -1
) -> StringName:
	var resolved_set := _resolve_weapon_set(target_slot, weapon_set)
	var key := _make_equipment_key(target_slot, slot_index, resolved_set)
	return StringName(_equipped_items.get(key, &""))


func get_equipped_item(
	target_slot: ItemData.EquipSlot,
	slot_index: int = 0,
	weapon_set: int = -1
) -> ItemData:
	if _inventory_component == null:
		return null
	return _inventory_component.get_item_data(
		get_equipped_item_id(target_slot, slot_index, weapon_set)
	)


func switch_weapon_set(set_index: int) -> bool:
	if not is_enabled or set_index < 0 or set_index >= WEAPON_SET_COUNT:
		return false
	if set_index == _active_weapon_set:
		return false

	var previous := _active_weapon_set
	_active_weapon_set = set_index
	weapon_set_changed.emit(previous, _active_weapon_set)
	equip(get_item_action_slot(get_equipped_item(ItemData.EquipSlot.MAIN_HAND)))
	return true


func cycle_weapon_set() -> int:
	switch_weapon_set((_active_weapon_set + 1) % WEAPON_SET_COUNT)
	return _active_weapon_set


func get_active_weapon_set() -> int:
	return _active_weapon_set


func meets_item_requirements(item: ItemData) -> bool:
	return (
		_attributes_component == null
		or _attributes_component.meets_item_requirements(item)
	)


func get_requirement_failure(item: ItemData) -> String:
	if _attributes_component == null:
		return ""
	return _attributes_component.get_requirement_failure(item)


func get_active_weapon_damage() -> float:
	var item := get_equipped_item(ItemData.EquipSlot.MAIN_HAND)
	return item.stats.damage if item != null and item.stats != null else 0.0


func get_total_defense() -> float:
	var total := 0.0
	for item: ItemData in _get_effective_equipped_items():
		if item.stats != null:
			total += item.stats.defense
	return total


func get_total_buff_value(buff_type: StringName) -> float:
	if buff_type.is_empty():
		return 0.0
	var total := 0.0
	for item: ItemData in _get_effective_equipped_items():
		if item.stats != null and item.stats.buff_type == buff_type:
			total += item.stats.buff_value
	return total


func get_item_action_slot(item: ItemData) -> Slot:
	if item == null:
		return Slot.MELEE
	match item.combat_mode:
		ItemData.CombatMode.THROWABLE:
			return Slot.THROWABLE
		ItemData.CombatMode.BOW:
			return Slot.BOW
		ItemData.CombatMode.CROSSBOW:
			return Slot.CROSSBOW
		ItemData.CombatMode.MAGIC:
			return Slot.MAGIC
		ItemData.CombatMode.MELEE:
			return Slot.MELEE
	match item.category:
		ItemData.Category.CONSUMABLE:
			return Slot.ITEM
		ItemData.Category.THROWABLE:
			return Slot.THROWABLE
		ItemData.Category.SCROLL:
			return Slot.MAGIC
		_:
			return Slot.MELEE


func get_slot_capacity(target_slot: ItemData.EquipSlot) -> int:
	match target_slot:
		ItemData.EquipSlot.RING:
			return 4
		ItemData.EquipSlot.RUNE:
			return 3
		ItemData.EquipSlot.EARRING:
			return 2
		ItemData.EquipSlot.NONE:
			return 0
		_:
			return 1


func capture_runtime_state() -> Variant:
	return {
		"action_slot": _current_slot,
		"active_weapon_set": _active_weapon_set,
		"equipped_items": _equipped_items.duplicate(),
	}


func restore_runtime_state(state: Variant) -> void:
	if not state is Dictionary:
		var legacy_slot := int(state)
		if legacy_slot >= 0 and legacy_slot < Slot.size():
			equip(legacy_slot as Slot)
		return

	var action_slot := int(state.get("action_slot", _current_slot))
	if action_slot >= 0 and action_slot < Slot.size():
		equip(action_slot as Slot)
	switch_weapon_set(
		clampi(int(state.get("active_weapon_set", 0)), 0, WEAPON_SET_COUNT - 1)
	)
	_equipped_items.clear()
	var equipped_state: Variant = state.get("equipped_items", {})
	if equipped_state is Dictionary:
		for key: Variant in equipped_state:
			var item_id := StringName(equipped_state[key])
			var item := (
				_inventory_component.get_item_data(item_id)
				if _inventory_component != null
				else null
			)
			if (
				item != null
				and meets_item_requirements(item)
			):
				_equipped_items[String(key)] = item_id


func _resolve_weapon_set(
	target_slot: ItemData.EquipSlot,
	requested_set: int
) -> int:
	if (
		target_slot == ItemData.EquipSlot.MAIN_HAND
		or target_slot == ItemData.EquipSlot.OFF_HAND
	):
		return _active_weapon_set if requested_set < 0 else requested_set
	return -1


func _is_valid_slot_index(
	target_slot: ItemData.EquipSlot,
	slot_index: int
) -> bool:
	return slot_index >= 0 and slot_index < get_slot_capacity(target_slot)


func _make_equipment_key(
	target_slot: ItemData.EquipSlot,
	slot_index: int,
	weapon_set: int
) -> String:
	return "%d:%d:%d" % [target_slot, slot_index, weapon_set]


func _on_inventory_changed() -> void:
	var previous_active_main := get_equipped_item_id(
		ItemData.EquipSlot.MAIN_HAND
	)
	var equipped_counts := {}
	for key: Variant in _equipped_items.keys():
		var item_id := StringName(_equipped_items[key])
		var used_count := int(equipped_counts.get(item_id, 0))
		if used_count >= _inventory_component.get_quantity(item_id):
			_remove_equipped_key(key)
		else:
			equipped_counts[item_id] = used_count + 1
	_update_mode_after_active_weapon_removal(previous_active_main)


func _count_equipped_item(item_id: StringName) -> int:
	var count := 0
	for equipped_id: Variant in _equipped_items.values():
		if StringName(equipped_id) == item_id:
			count += 1
	return count


func _equip_starting_weapon_sets() -> void:
	if _inventory_component == null or not _inventory_component.is_enabled:
		return
	for set_index in WEAPON_SET_COUNT:
		if set_index < starting_main_hand_ids.size():
			var main_id := starting_main_hand_ids[set_index]
			if not main_id.is_empty() and _inventory_component.has_item(main_id):
				equip_inventory_item(
					main_id, ItemData.EquipSlot.MAIN_HAND, 0, set_index
				)
		if set_index < starting_off_hand_ids.size():
			var off_id := starting_off_hand_ids[set_index]
			if not off_id.is_empty() and _inventory_component.has_item(off_id):
				equip_inventory_item(
					off_id, ItemData.EquipSlot.OFF_HAND, 0, set_index
				)


func _get_effective_equipped_items() -> Array[ItemData]:
	var result: Array[ItemData] = []
	_append_equipped_item(
		result, ItemData.EquipSlot.MAIN_HAND, 0, _active_weapon_set
	)
	_append_equipped_item(
		result, ItemData.EquipSlot.OFF_HAND, 0, _active_weapon_set
	)
	for slot: ItemData.EquipSlot in [
		ItemData.EquipSlot.HEAD,
		ItemData.EquipSlot.CHEST,
		ItemData.EquipSlot.HANDS,
		ItemData.EquipSlot.LEGS,
		ItemData.EquipSlot.AMULET,
		ItemData.EquipSlot.BELT,
		ItemData.EquipSlot.FEET,
		ItemData.EquipSlot.SHOULDER,
		ItemData.EquipSlot.ARTIFACT,
		ItemData.EquipSlot.BROOCH,
	]:
		_append_equipped_item(result, slot)
	for index in 4:
		_append_equipped_item(result, ItemData.EquipSlot.RING, index)
	for index in 2:
		_append_equipped_item(result, ItemData.EquipSlot.EARRING, index)
	for index in 3:
		_append_equipped_item(result, ItemData.EquipSlot.RUNE, index)
	return result


func _append_equipped_item(
	result: Array[ItemData],
	slot: ItemData.EquipSlot,
	index: int = 0,
	weapon_set: int = -1
) -> void:
	var item := get_equipped_item(slot, index, weapon_set)
	if item != null:
		result.append(item)


func _on_attributes_changed(_strength: int, _dexterity: int) -> void:
	if _inventory_component == null:
		return
	var previous_active_main := get_equipped_item_id(
		ItemData.EquipSlot.MAIN_HAND
	)
	for key: Variant in _equipped_items.keys():
		var item := _inventory_component.get_item_data(
			StringName(_equipped_items[key])
		)
		if item == null or not meets_item_requirements(item):
			_remove_equipped_key(key)
	_update_mode_after_active_weapon_removal(previous_active_main)


func _update_mode_after_active_weapon_removal(
	previous_active_main: StringName
) -> void:
	if (
		not previous_active_main.is_empty()
		and get_equipped_item_id(ItemData.EquipSlot.MAIN_HAND).is_empty()
	):
		equip(Slot.MELEE)


func _remove_equipped_key(key: Variant) -> void:
	if not _equipped_items.has(key):
		return
	var previous := StringName(_equipped_items[key])
	var parts := String(key).split(":")
	_equipped_items.erase(key)
	if parts.size() != 3:
		return
	loadout_item_changed.emit(
		int(parts[0]) as ItemData.EquipSlot,
		int(parts[1]),
		int(parts[2]),
		previous,
		&""
	)
