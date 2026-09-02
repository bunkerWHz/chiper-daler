extends Component
class_name InventoryComponent

signal item_added(item: ItemData, quantity: int)
signal item_removed(item: ItemData, quantity: int)
signal inventory_changed

@export var config: InventoryConfig

var _stacks: Array[InventoryStack] = []


func on_initialize() -> void:
	if config == null or config.capacity <= 0:
		push_error("InventoryComponent requires a valid InventoryConfig")
		disable()
		return

	for index in mini(config.starting_items.size(), config.starting_quantities.size()):
		add_item(config.starting_items[index], config.starting_quantities[index])


func add_item(item: ItemData, quantity: int = 1) -> int:
	if not is_enabled or item == null or not item.is_valid() or quantity <= 0:
		return 0
	if item.is_flask():
		if has_item(item.id):
			return 0
		quantity = 1

	var remaining := quantity
	if item.stackable:
		for stack: InventoryStack in _stacks:
			if not stack.can_merge(item):
				continue
			var added := mini(stack.get_available_space(), remaining)
			stack.quantity += added
			remaining -= added
			if remaining == 0:
				break

	while remaining > 0 and _stacks.size() < config.capacity:
		var stack_quantity := mini(item.get_effective_stack_size(), remaining)
		_stacks.append(InventoryStack.new(item, stack_quantity))
		remaining -= stack_quantity

	var accepted := quantity - remaining
	if accepted > 0:
		item_added.emit(item, accepted)
		inventory_changed.emit()
	return accepted


func remove_item(item_id: StringName, quantity: int = 1) -> int:
	if not is_enabled or item_id.is_empty() or quantity <= 0:
		return 0
	var item := get_item_data(item_id)
	if item != null and item.is_flask():
		return 0

	var remaining := quantity
	var removed_item: ItemData
	for index in range(_stacks.size() - 1, -1, -1):
		var stack := _stacks[index]
		if stack.item.id != item_id:
			continue
		removed_item = stack.item
		var removed := mini(stack.quantity, remaining)
		stack.quantity -= removed
		remaining -= removed
		if stack.quantity == 0:
			_stacks.remove_at(index)
		if remaining == 0:
			break

	var removed_total := quantity - remaining
	if removed_total > 0:
		item_removed.emit(removed_item, removed_total)
		inventory_changed.emit()
	return removed_total


func get_quantity(item_id: StringName) -> int:
	var total := 0
	for stack: InventoryStack in _stacks:
		if stack.item.id == item_id:
			total += stack.quantity
	return total


func get_item_data(item_id: StringName) -> ItemData:
	for stack: InventoryStack in _stacks:
		if stack.item.id == item_id:
			return stack.item
	return null


func has_item(item_id: StringName, quantity: int = 1) -> bool:
	return quantity > 0 and get_quantity(item_id) >= quantity


func can_split_stack(item_id: StringName) -> bool:
	if _stacks.size() >= config.capacity:
		return false
	for stack: InventoryStack in _stacks:
		if stack.item.id == item_id and stack.item.stackable and stack.quantity > 1:
			return true
	return false


func split_stack(item_id: StringName, quantity: int = -1) -> bool:
	if not is_enabled or not can_split_stack(item_id):
		return false
	for stack: InventoryStack in _stacks:
		if stack.item.id != item_id or not stack.item.stackable or stack.quantity <= 1:
			continue
		var split_quantity := quantity
		if split_quantity <= 0:
			split_quantity = floori(float(stack.quantity) / 2.0)
		split_quantity = clampi(split_quantity, 1, stack.quantity - 1)
		stack.quantity -= split_quantity
		_stacks.append(InventoryStack.new(stack.item, split_quantity))
		inventory_changed.emit()
		return true
	return false


func get_stacks() -> Array[InventoryStack]:
	var result: Array[InventoryStack] = []
	for stack: InventoryStack in _stacks:
		result.append(stack.duplicate_stack())
	return result


func get_used_slots() -> int:
	return _stacks.size()


func get_capacity() -> int:
	return config.capacity


func get_total_weight() -> float:
	var total := 0.0
	for stack: InventoryStack in _stacks:
		total += stack.item.weight * stack.quantity
	return total


func capture_runtime_state() -> Variant:
	var result: Array[Dictionary] = []
	for stack: InventoryStack in _stacks:
		result.append({
			"item": stack.item,
			"quantity": stack.quantity,
		})
	return result


func restore_runtime_state(state: Variant) -> void:
	if not state is Array:
		return

	_stacks.clear()
	for entry: Variant in state:
		if not entry is Dictionary:
			continue
		var item: ItemData = entry.get("item") as ItemData
		var quantity := int(entry.get("quantity", 0))
		if item != null and item.is_valid() and quantity > 0:
			add_item(item, quantity)

	inventory_changed.emit()


func get_runtime_state_restore_priority() -> int:
	return -100
