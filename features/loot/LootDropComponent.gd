extends Component
class_name LootDropComponent

signal loot_dropped(bag: LootBag)

@export var loot_bag_scene: PackedScene
@export var loot_entries: Array[LootEntry] = []

var _health: HealthComponent
var _has_dropped: bool = false


func on_initialize() -> void:
	if loot_bag_scene == null or not _has_valid_entry():
		push_error("LootDropComponent requires a loot bag scene and valid loot")
		disable()
		return

	_health = actor.get_component(HealthComponent) as HealthComponent
	if _health == null or not _health.is_enabled:
		push_error("LootDropComponent requires an enabled HealthComponent")
		disable()
		return

	_health.died.connect(_on_health_died)


func should_disable_on_actor_death() -> bool:
	return false


func _on_health_died() -> void:
	if _has_dropped:
		return
	_has_dropped = true

	var parent := actor.get_parent()
	var bag := loot_bag_scene.instantiate() as LootBag
	if parent == null or bag == null:
		return

	for entry: LootEntry in loot_entries:
		if entry == null:
			continue
		var rolled_quantity := entry.roll_quantity()
		if rolled_quantity > 0:
			bag.add_item(entry.item, rolled_quantity)
	if bag.is_empty():
		bag.free()
		return

	parent.add_child(bag)
	bag.global_position = actor.global_position
	loot_dropped.emit(bag)


func _has_valid_entry() -> bool:
	for entry: LootEntry in loot_entries:
		if entry != null and entry.is_valid():
			return true
	return false
