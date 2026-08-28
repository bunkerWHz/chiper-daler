extends Component
class_name LootDropComponent

signal loot_dropped(pickup: Pickup)

@export var pickup_scene: PackedScene
@export var pickup_item: ItemData
@export_range(1, 999, 1) var quantity: int = 1
@export_range(0.0, 1.0, 0.01) var drop_chance: float = 1.0

var _health: HealthComponent
var _has_dropped: bool = false


func on_initialize() -> void:
	if (
		pickup_scene == null
		or pickup_item == null
		or not pickup_item.is_valid()
		or quantity <= 0
	):
		push_error("LootDropComponent requires a pickup scene and valid item")
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
	if _has_dropped or randf() > drop_chance:
		return

	var parent := actor.get_parent()
	var pickup := pickup_scene.instantiate() as Pickup
	if parent == null or pickup == null:
		return

	_has_dropped = true
	pickup.item = pickup_item
	pickup.quantity = quantity
	parent.add_child(pickup)
	pickup.global_position = actor.global_position
	loot_dropped.emit(pickup)
