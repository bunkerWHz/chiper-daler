extends Resource
class_name InventoryConfig

@export_range(1, 999, 1) var capacity: int = 40
@export var starting_items: Array[ItemData] = []
@export var starting_quantities: Array[int] = []
