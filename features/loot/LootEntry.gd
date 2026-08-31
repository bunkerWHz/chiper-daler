extends Resource
class_name LootEntry

@export var item: ItemData
@export_range(1, 999, 1) var minimum_quantity: int = 1
@export_range(1, 999, 1) var maximum_quantity: int = 1
@export_range(0.0, 1.0, 0.01) var drop_chance: float = 1.0


func is_valid() -> bool:
	return (
		item != null
		and item.is_valid()
		and not item.is_flask()
		and minimum_quantity > 0
		and maximum_quantity >= minimum_quantity
	)


func roll_quantity() -> int:
	if not is_valid() or randf() > drop_chance:
		return 0
	return randi_range(minimum_quantity, maximum_quantity)
