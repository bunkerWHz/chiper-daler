extends Component
class_name InventoryDropComponent

signal item_dropped(bag: LootBag, item: ItemData, quantity: int)

@export var loot_bag_scene: PackedScene

var _inventory: InventoryComponent


func on_initialize() -> void:
	_inventory = actor.get_component(InventoryComponent) as InventoryComponent
	if loot_bag_scene == null or _inventory == null or not _inventory.is_enabled:
		push_error("InventoryDropComponent requires inventory and a loot bag scene")
		disable()


func drop_item(item_id: StringName, quantity: int = 1) -> LootBag:
	if not is_enabled or item_id.is_empty() or quantity <= 0:
		return null
	var item := _inventory.get_item_data(item_id)
	if item == null or item.is_key_item:
		return null
	var parent := actor.get_parent()
	var bag := loot_bag_scene.instantiate() as LootBag
	if parent == null or bag == null:
		if bag != null:
			bag.free()
		return null

	var removed := _inventory.remove_item(
		item_id,
		mini(quantity, _inventory.get_quantity(item_id))
	)
	if removed <= 0:
		bag.free()
		return null
	bag.add_item(item, removed)
	parent.add_child(bag)
	bag.global_position = actor.global_position
	item_dropped.emit(bag, item, removed)
	return bag
