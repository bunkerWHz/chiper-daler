extends RefCounted
class_name InventoryStack

var item: ItemData
var quantity: int


func _init(stack_item: ItemData, stack_quantity: int = 1) -> void:
	item = stack_item
	quantity = stack_quantity


func get_available_space() -> int:
	if item == null:
		return 0
	return maxi(item.get_effective_stack_size() - quantity, 0)


func can_merge(other_item: ItemData) -> bool:
	return (
		item != null
		and other_item != null
		and item.id == other_item.id
		and item.stackable
		and get_available_space() > 0
	)


func duplicate_stack() -> InventoryStack:
	return InventoryStack.new(item, quantity)
