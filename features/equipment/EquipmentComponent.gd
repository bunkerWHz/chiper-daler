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

signal operation_rejected(reason: String)

signal equipment_changed(previous_slot: Slot, current_slot: Slot)
signal weapon_set_changed(previous_set: int, current_set: int)
signal loadout_item_changed(
	equip_slot: ItemData.EquipSlot,
	slot_index: int,
	weapon_set: int,
	previous_item_id: StringName,
	current_item_id: StringName
)
signal equipment_load_changed(
	current_weight: float,
	maximum_weight: float,
	load_ratio: float
)

const WEAPON_SET_COUNT := 2

@export var default_slot: Slot = Slot.MELEE
@export var starting_main_hand_ids: Array[StringName] = []
@export var starting_off_hand_ids: Array[StringName] = []

var _inventory_component: InventoryComponent
var _attributes_component: CharacterAttributesComponent
var _current_slot: Slot = Slot.MELEE
var _active_weapon_set: int = 0
var _equipped_items: Dictionary = {}


func on_initialize() -> void:
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

	_current_slot = default_slot
	if _inventory_component != null and _inventory_component.is_enabled:
		if not _inventory_component.inventory_changed.is_connected(
			_on_inventory_changed
		):
			_inventory_component.inventory_changed.connect(
				_on_inventory_changed
			)


func _ready() -> void:
	_equip_starting_weapon_sets()


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


func allows_light_attack() -> bool:
	return _allows_weapon_action(ItemWeaponProfile.Action.LIGHT_ATTACK)


func allows_heavy_attack() -> bool:
	return _allows_weapon_action(ItemWeaponProfile.Action.HEAVY_ATTACK)


func allows_guard() -> bool:
	return _allows_defensive_action(
		ItemWeaponProfile.Action.GUARD,
		ItemOffhandProfile.Action.GUARD
	)


func allows_parry() -> bool:
	return _allows_defensive_action(
		ItemWeaponProfile.Action.PARRY,
		ItemOffhandProfile.Action.PARRY
	)


func allows_bow_aim() -> bool:
	return _allows_mode_weapon_action(
		Slot.BOW, ItemWeaponProfile.Action.AIM
	)


func allows_bow_fire() -> bool:
	return _allows_mode_weapon_action(
		Slot.BOW, ItemWeaponProfile.Action.FIRE
	)


func allows_crossbow_aim() -> bool:
	return _allows_mode_weapon_action(
		Slot.CROSSBOW, ItemWeaponProfile.Action.AIM
	)


func allows_crossbow_fire() -> bool:
	return _allows_mode_weapon_action(
		Slot.CROSSBOW, ItemWeaponProfile.Action.FIRE
	)


func allows_magic_cast() -> bool:
	return _allows_mode_weapon_action(
		Slot.MAGIC, ItemWeaponProfile.Action.CAST
	)


func allows_magic_channel() -> bool:
	return _allows_mode_weapon_action(
		Slot.MAGIC, ItemWeaponProfile.Action.CHANNEL
	)


func equip_inventory_item(
	item_id: StringName,
	target_slot: ItemData.EquipSlot,
	slot_index: int = 0,
	weapon_set: int = -1
) -> bool:
	if not is_enabled or _inventory_component == null:
		return _reject_operation("Equipment is unavailable.")
	var resolved_set := _resolve_weapon_set(target_slot, weapon_set)
	if not _is_valid_address(target_slot, slot_index, resolved_set):
		return _reject_operation("Choose a valid equipment slot.")
	var key := _make_equipment_key(target_slot, slot_index, resolved_set)
	if StringName(_equipped_items.get(key, &"")) == item_id:
		return _reject_operation("This item is already equipped in that slot.")
	var candidate := _equipped_items.duplicate()
	candidate[key] = item_id
	if target_slot == ItemData.EquipSlot.MAIN_HAND:
		_reconcile_hands(candidate, [resolved_set])
	var failure := _get_loadout_failure(candidate)
	if not failure.is_empty():
		return _reject_operation(failure)
	return _commit_loadout(candidate)


## Move an equipped item, swapping the displaced item back when compatible.
## Items that cannot return to the source slot remain in the inventory.
func move_equipped_item(
	source_slot: ItemData.EquipSlot,
	source_index: int,
	source_weapon_set: int,
	target_slot: ItemData.EquipSlot,
	target_index: int,
	target_weapon_set: int
) -> bool:
	if not is_enabled or _inventory_component == null:
		return _reject_operation("Equipment is unavailable.")
	source_weapon_set = _resolve_weapon_set(source_slot, source_weapon_set)
	target_weapon_set = _resolve_weapon_set(target_slot, target_weapon_set)
	if (
		not _is_valid_address(source_slot, source_index, source_weapon_set)
		or not _is_valid_address(target_slot, target_index, target_weapon_set)
	):
		return _reject_operation("Choose a valid equipment slot.")
	var source_key := _make_equipment_key(source_slot, source_index, source_weapon_set)
	var target_key := _make_equipment_key(target_slot, target_index, target_weapon_set)
	var source_item := _loadout_item(_equipped_items, source_key)
	if source_key == target_key:
		return false
	if source_item == null:
		return _reject_operation("There is no item in the source slot.")
	if not source_item.can_equip_in(target_slot):
		return _reject_operation("%s does not fit this slot." % source_item.display_name)
	var displaced := _loadout_item(_equipped_items, target_key)
	var candidate := _equipped_items.duplicate()
	candidate.erase(source_key)
	candidate[target_key] = source_item.id
	if displaced != null and displaced.can_equip_in(source_slot):
		candidate[source_key] = displaced.id

	var changed_sets: Array[int] = []
	if source_slot == ItemData.EquipSlot.MAIN_HAND:
		changed_sets.append(source_weapon_set)
	if target_slot == ItemData.EquipSlot.MAIN_HAND and target_weapon_set not in changed_sets:
		changed_sets.append(target_weapon_set)
	_reconcile_hands(candidate, changed_sets)
	# Reconciliation may return an incompatible displaced offhand to the bag,
	# but must never discard the item the player explicitly moved.
	if StringName(candidate.get(target_key, &"")) != source_item.id:
		return _reject_operation("This item is incompatible with the weapon in that set.")
	var failure := _get_loadout_failure(candidate)
	if not failure.is_empty():
		return _reject_operation(failure)
	return _commit_loadout(candidate)


func unequip_item(
	target_slot: ItemData.EquipSlot,
	slot_index: int = 0,
	weapon_set: int = -1
) -> bool:
	var resolved_set := _resolve_weapon_set(target_slot, weapon_set)
	var key := _make_equipment_key(target_slot, slot_index, resolved_set)
	if not _equipped_items.has(key):
		return false
	var candidate := _equipped_items.duplicate()
	candidate.erase(key)
	if target_slot == ItemData.EquipSlot.MAIN_HAND:
		_reconcile_hands(candidate, [resolved_set])
	return _commit_loadout(candidate)


func is_item_equipped(item_id: StringName) -> bool:
	return not item_id.is_empty() and _equipped_items.values().has(item_id)


func get_equipped_item_count(item_id: StringName) -> int:
	if item_id.is_empty():
		return 0
	if _inventory_component != null and is_item_equipped(item_id):
		var item := _inventory_component.get_item_data(item_id)
		if item != null and item.category == ItemData.Category.AMMUNITION:
			return _inventory_component.get_quantity(item_id)
	return _count_equipped_item(item_id)


func unequip_inventory_item(item_id: StringName) -> bool:
	if item_id.is_empty():
		return false
	for key: String in _equipped_items:
		if StringName(_equipped_items[key]) == item_id:
			var parts := key.split(":")
			return unequip_item(int(parts[0]) as ItemData.EquipSlot, int(parts[1]), int(parts[2]))
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
	return _commit_loadout(_equipped_items.duplicate(), set_index)


func cycle_weapon_set() -> int:
	switch_weapon_set((_active_weapon_set + 1) % WEAPON_SET_COUNT)
	return _active_weapon_set


func get_active_weapon_set() -> int:
	return _active_weapon_set


func is_off_hand_available(weapon_set: int = -1) -> bool:
	var resolved_set := (
		_active_weapon_set if weapon_set < 0 else weapon_set
	)
	if resolved_set < 0 or resolved_set >= WEAPON_SET_COUNT:
		return false
	var main_hand := get_equipped_item(
		ItemData.EquipSlot.MAIN_HAND, 0, resolved_set
	)
	return main_hand == null or not main_hand.is_two_handed_weapon()


func is_ammunition_compatible(
	ammunition: ItemData,
	weapon_set: int = -1
) -> bool:
	if ammunition == null or ammunition.category != ItemData.Category.AMMUNITION:
		return false
	var resolved_set := _active_weapon_set if weapon_set < 0 else weapon_set
	if resolved_set < 0 or resolved_set >= WEAPON_SET_COUNT:
		return false
	var main_hand := get_equipped_item(
		ItemData.EquipSlot.MAIN_HAND, 0, resolved_set
	)
	return (
		main_hand != null
		and not main_hand.get_ammunition_type().is_empty()
		and main_hand.get_ammunition_type() == ammunition.get_ammunition_type()
	)


func get_active_weapon_damage() -> float:
	var item := get_equipped_item(ItemData.EquipSlot.MAIN_HAND)
	var item_stats := item.get_equipment_stats() if item != null else null
	if item_stats == null:
		return 0.0
	return item_stats.damage * (1.0 + 0.1 * _inventory_component.get_weapon_upgrade(item.id))


func get_active_weapon_reach_multiplier() -> float:
	var item := get_equipped_item(ItemData.EquipSlot.MAIN_HAND)
	return (
		clampf(item.weapon_profile.reach_multiplier, 0.1, 5.0)
		if item != null and item.weapon_profile != null
		else 1.0
	)


func get_active_weapon_critical_multiplier(fallback: float = 2.0) -> float:
	var item := get_equipped_item(ItemData.EquipSlot.MAIN_HAND)
	return (
		item.weapon_profile.critical_damage_multiplier
		if item != null and item.weapon_profile != null
		else fallback
	)


func get_active_block_damage_multiplier(fallback: float) -> float:
	var off_hand := get_equipped_item(ItemData.EquipSlot.OFF_HAND)
	return (
		1.0 - off_hand.offhand_profile.block_damage_reduction
		if off_hand != null and off_hand.offhand_profile != null
		else fallback
	)


func get_active_parry_window_multiplier() -> float:
	var off_hand := get_equipped_item(ItemData.EquipSlot.OFF_HAND)
	return (
		off_hand.offhand_profile.parry_window_multiplier
		if off_hand != null and off_hand.offhand_profile != null
		else 1.0
	)


func get_total_defense() -> float:
	var total := 0.0
	for item: ItemData in _get_effective_equipped_items():
		var item_stats := item.get_equipment_stats()
		if item_stats != null:
			total += item_stats.defense
	return total


func get_total_poise() -> float:
	var total := 0.0
	for item: ItemData in _get_effective_equipped_items():
		if item.armor_profile != null:
			total += item.armor_profile.poise
	return total


func get_total_equipped_weight() -> float:
	if _inventory_component == null:
		return 0.0
	var total := 0.0
	for equipped_id: Variant in _equipped_items.values():
		var item := _inventory_component.get_item_data(
			StringName(equipped_id)
		)
		if item != null:
			total += item.weight * (_inventory_component.get_quantity(item.id) if item.category == ItemData.Category.AMMUNITION else 1)
	return total


func get_max_equip_load() -> float:
	return (
		_attributes_component.get_max_equip_load()
		if _attributes_component != null
		else 1.0
	)


func get_equip_load_ratio() -> float:
	return get_total_equipped_weight() / get_max_equip_load()


func get_total_buff_value(buff_type: StringName) -> float:
	if buff_type.is_empty():
		return 0.0
	var total := 0.0
	for item: ItemData in _get_effective_equipped_items():
		var item_stats := item.get_equipment_stats()
		if item_stats != null and item_stats.buff_type == buff_type:
			total += item_stats.buff_value
	return total


func get_item_action_slot(item: ItemData) -> Slot:
	if item == null:
		return Slot.MELEE
	match item.get_combat_mode():
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
		return
	var candidate: Dictionary = {}
	var equipped_state: Variant = state.get("equipped_items", {})
	if equipped_state is Dictionary:
		candidate = equipped_state.duplicate()
	_prune_unavailable_items(candidate)
	_reconcile_hands(candidate, [0, 1], false)
	var next_set := clampi(int(state.get("active_weapon_set", 0)), 0, WEAPON_SET_COUNT - 1)
	var next_mode := int(state.get("action_slot", _current_slot))
	if next_mode < 0 or next_mode >= Slot.size():
		next_mode = int(_current_slot)
	# Old quick-slot saves used a throwable/item context instead of the held weapon.
	if next_mode == Slot.THROWABLE or next_mode == Slot.ITEM:
		next_mode = get_item_action_slot(_loadout_item(candidate, _make_equipment_key(
			ItemData.EquipSlot.MAIN_HAND, 0, next_set)))
	_commit_loadout(candidate, next_set, next_mode)


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


func _allows_weapon_action(action: ItemWeaponProfile.Action) -> bool:
	if not allows_melee_actions():
		return false
	var main_hand := get_equipped_item(ItemData.EquipSlot.MAIN_HAND)
	return (
		main_hand.weapon_profile == null
		or main_hand.has_weapon_action(action)
	)


func _allows_defensive_action(
	weapon_action: ItemWeaponProfile.Action,
	offhand_action: ItemOffhandProfile.Action
) -> bool:
	if not allows_melee_actions():
		return false
	var main_hand := get_equipped_item(ItemData.EquipSlot.MAIN_HAND)
	if (
		main_hand.weapon_profile == null
		or main_hand.has_weapon_action(weapon_action)
	):
		return true
	var off_hand := get_equipped_item(ItemData.EquipSlot.OFF_HAND)
	return (
		off_hand != null
		and (
			off_hand.offhand_profile == null
			or off_hand.has_offhand_action(offhand_action)
		)
	)


func _allows_mode_weapon_action(
	mode: Slot,
	action: ItemWeaponProfile.Action
) -> bool:
	if not is_slot_active(mode):
		return false
	var main_hand := get_equipped_item(ItemData.EquipSlot.MAIN_HAND)
	if main_hand == null:
		return true
	return (
		get_item_action_slot(main_hand) == mode
		and (
			main_hand.weapon_profile == null
			or main_hand.has_weapon_action(action)
		)
	)


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
	var candidate := _equipped_items.duplicate()
	_prune_unavailable_items(candidate)
	_reconcile_changed_hands(candidate)
	if not _commit_loadout(candidate):
		# Ammo quantities can change without changing the selected item ID.
		_emit_equipment_load_changed()


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


func _on_attributes_changed(
	_strength: int,
	_dexterity: int,
	_intelligence: int,
	_endurance: int,
	_wisdom: int
) -> void:
	_emit_equipment_load_changed()


func _emit_equipment_load_changed() -> void:
	equipment_load_changed.emit(
		get_total_equipped_weight(),
		get_max_equip_load(),
		get_equip_load_ratio()
	)


func _is_valid_address(slot: ItemData.EquipSlot, index: int, weapon_set: int) -> bool:
	var hand_slot := slot in [ItemData.EquipSlot.MAIN_HAND, ItemData.EquipSlot.OFF_HAND]
	return (
		slot > ItemData.EquipSlot.NONE and slot < ItemData.EquipSlot.size()
		and _is_valid_slot_index(slot, index)
		and ((weapon_set >= 0 and weapon_set < WEAPON_SET_COUNT) if hand_slot else weapon_set == -1)
	)


func _loadout_item(loadout: Dictionary, key: String) -> ItemData:
	if _inventory_component == null:
		return null
	return _inventory_component.get_item_data(StringName(loadout.get(key, &"")))


func _get_loadout_failure(loadout: Dictionary) -> String:
	var counts := {}
	for key: String in loadout:
		var parts := key.split(":")
		if parts.size() != 3:
			return "Choose a valid equipment slot."
		var slot := int(parts[0]) as ItemData.EquipSlot
		var weapon_set := int(parts[2])
		var item := _loadout_item(loadout, key)
		if not _is_valid_address(slot, int(parts[1]), weapon_set):
			return "Choose a valid equipment slot."
		if item == null:
			return "This item is no longer in your inventory."
		if not item.can_equip_in(slot):
			return "%s does not fit this slot." % item.display_name
		counts[item.id] = int(counts.get(item.id, 0)) + 1
		var available := 1 if item.category == ItemData.Category.AMMUNITION else _inventory_component.get_quantity(item.id)
		if int(counts[item.id]) > available:
			return "All copies of %s are already equipped." % item.display_name
		if slot == ItemData.EquipSlot.OFF_HAND:
			var main := _loadout_item(loadout, _make_equipment_key(
				ItemData.EquipSlot.MAIN_HAND, 0, weapon_set
			))
			if not _offhand_fits(main, item):
				return (
					"These ammunition and weapon types do not match."
					if item.category == ItemData.Category.AMMUNITION
					else "The weapon in this set reserves the off hand."
				)
	return ""


func _offhand_fits(main: ItemData, offhand: ItemData) -> bool:
	if offhand == null:
		return true
	if offhand.category == ItemData.Category.AMMUNITION:
		return (
			main != null and not main.get_ammunition_type().is_empty()
			and main.get_ammunition_type() == offhand.get_ammunition_type()
		)
	return (
		main == null
		or (not main.is_two_handed_weapon() and main.get_ammunition_type().is_empty())
	)


## Reconcile all changed hands before selecting ammunition, so a scarce stack
## released by one weapon set is available to the other set in the same swap.
func _reconcile_hands(loadout: Dictionary, weapon_sets: Array[int], select_ammunition: bool = true) -> void:
	for weapon_set: int in weapon_sets:
		var main := _loadout_item(loadout, _make_equipment_key(
			ItemData.EquipSlot.MAIN_HAND, 0, weapon_set
		))
		var off_key := _make_equipment_key(ItemData.EquipSlot.OFF_HAND, 0, weapon_set)
		if not _offhand_fits(main, _loadout_item(loadout, off_key)):
			loadout.erase(off_key)
	if _inventory_component == null or not select_ammunition:
		return
	for weapon_set: int in weapon_sets:
		var main := _loadout_item(loadout, _make_equipment_key(
			ItemData.EquipSlot.MAIN_HAND, 0, weapon_set
		))
		var off_key := _make_equipment_key(ItemData.EquipSlot.OFF_HAND, 0, weapon_set)
		if main == null or main.get_ammunition_type().is_empty() or loadout.has(off_key):
			continue
		for stack: InventoryStack in _inventory_component.get_stacks():
			var ammo := stack.item
			if (
				ammo.category == ItemData.Category.AMMUNITION
				and ammo.can_equip_in(ItemData.EquipSlot.OFF_HAND)
				and _offhand_fits(main, ammo)
				and not loadout.values().has(ammo.id)
			):
				loadout[off_key] = ammo.id
				break


## Publish only after both the full loadout and its combat mode are installed.
func _commit_loadout(candidate: Dictionary, next_set: int = -1, next_mode: int = -1) -> bool:
	if next_set < 0:
		next_set = _active_weapon_set
	if candidate == _equipped_items and next_set == _active_weapon_set and (
		next_mode < 0 or next_mode == int(_current_slot)
	):
		return false
	var previous := _equipped_items
	var previous_mode := _current_slot
	var previous_set := _active_weapon_set
	var main_key := _make_equipment_key(ItemData.EquipSlot.MAIN_HAND, 0, next_set)
	_equipped_items = candidate
	_active_weapon_set = next_set
	if next_mode >= 0:
		_current_slot = next_mode as Slot
	elif previous_set != next_set or previous.get(main_key, &"") != candidate.get(main_key, &""):
		_current_slot = get_item_action_slot(_loadout_item(candidate, main_key))
	var changed_keys := previous.keys()
	for key: String in candidate:
		if key not in changed_keys:
			changed_keys.append(key)
	for key: String in changed_keys:
		var before := StringName(previous.get(key, &""))
		var after := StringName(candidate.get(key, &""))
		if before == after:
			continue
		var parts := key.split(":")
		loadout_item_changed.emit(
			int(parts[0]) as ItemData.EquipSlot, int(parts[1]), int(parts[2]), before, after
		)
	if previous_set != _active_weapon_set:
		weapon_set_changed.emit(previous_set, _active_weapon_set)
	if previous_mode != _current_slot:
		equipment_changed.emit(previous_mode, _current_slot)
	_emit_equipment_load_changed()
	return true

func _prune_unavailable_items(candidate: Dictionary) -> void:
	var counts := {}
	for key: Variant in candidate.keys():
		var parts := String(key).split(":")
		var item := _loadout_item(candidate, String(key))
		if parts.size() != 3 or item == null:
			candidate.erase(key)
			continue
		var slot := int(parts[0]) as ItemData.EquipSlot
		var weapon_set := int(parts[2])
		if (
			not _is_valid_address(slot, int(parts[1]), weapon_set)
			or not item.can_equip_in(slot)
			or int(counts.get(item.id, 0)) >= (1 if item.category == ItemData.Category.AMMUNITION else _inventory_component.get_quantity(item.id))
		):
			candidate.erase(key)
			continue
		counts[item.id] = int(counts.get(item.id, 0)) + 1


func _reconcile_changed_hands(candidate: Dictionary) -> void:
	var changed_sets: Array[int] = []
	for weapon_set in WEAPON_SET_COUNT:
		var key := _make_equipment_key(ItemData.EquipSlot.MAIN_HAND, 0, weapon_set)
		if candidate.get(key, &"") != _equipped_items.get(key, &""):
			changed_sets.append(weapon_set)
	_reconcile_hands(candidate, changed_sets)


func _reject_operation(reason: String) -> bool:
	operation_rejected.emit(reason)
	return false
