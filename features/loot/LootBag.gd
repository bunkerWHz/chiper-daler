extends Actor
class_name LootBag

signal item_collected(collector: Actor, item: ItemData, quantity: int)

var _stacks: Array[InventoryStack] = []
var _interactable: InteractableComponent


func _ready() -> void:
	_interactable = get_component(InteractableComponent) as InteractableComponent
	if _interactable == null:
		push_error("LootBag requires an InteractableComponent")
		return
	_interactable.interacted_by.connect(_on_interacted_by)
	_update_interaction_state()


func add_item(item: ItemData, quantity: int = 1) -> int:
	if (
		item == null
		or not item.is_valid()
		or item.is_flask()
		or quantity <= 0
	):
		return 0

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

	while remaining > 0:
		var stack_quantity := mini(item.get_effective_stack_size(), remaining)
		_stacks.append(InventoryStack.new(item, stack_quantity))
		remaining -= stack_quantity

	_update_interaction_state()
	return quantity


func add_stacks(stacks: Array[InventoryStack]) -> int:
	var added_total := 0
	for stack: InventoryStack in stacks:
		if stack != null:
			added_total += add_item(stack.item, stack.quantity)
	return added_total


func try_collect(collector: Actor) -> bool:
	if collector == null or _stacks.is_empty():
		return false
	var inventory := collector.get_component(InventoryComponent) as InventoryComponent
	if inventory == null or not inventory.is_enabled:
		return false

	var collected_any := false
	for index in range(_stacks.size() - 1, -1, -1):
		var stack := _stacks[index]
		var accepted := inventory.add_item(stack.item, stack.quantity)
		if accepted <= 0:
			continue
		collected_any = true
		stack.quantity -= accepted
		item_collected.emit(collector, stack.item, accepted)
		if stack.quantity == 0:
			_stacks.remove_at(index)

	_update_interaction_state()
	if _stacks.is_empty():
		queue_free()
	return collected_any


func get_stacks() -> Array[InventoryStack]:
	var result: Array[InventoryStack] = []
	for stack: InventoryStack in _stacks:
		result.append(stack.duplicate_stack())
	return result


func get_total_quantity() -> int:
	var total := 0
	for stack: InventoryStack in _stacks:
		total += stack.quantity
	return total


func is_empty() -> bool:
	return _stacks.is_empty()


func _on_interacted_by(interactor: Actor) -> void:
	try_collect(interactor)


func _update_interaction_state() -> void:
	if _interactable == null:
		return
	if _stacks.is_empty():
		_interactable.interaction_name = "Empty loot bag"
		_interactable.disable_interaction()
	else:
		_interactable.interaction_name = "Loot bag (%d)" % get_total_quantity()
		_interactable.enable_interaction()
