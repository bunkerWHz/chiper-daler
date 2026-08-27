extends Component
class_name LootDropComponent

signal loot_dropped(pickup: Pickup)

@export var pickup_scene: PackedScene
@export var pickup_data: PickupData
@export_range(0.0, 1.0, 0.01) var drop_chance: float = 1.0

var _health: HealthComponent
var _has_dropped: bool = false


func on_initialize() -> void:
	if pickup_scene == null or pickup_data == null or not pickup_data.is_valid():
		push_error("LootDropComponent requires a pickup scene and valid data")
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
	pickup.data = pickup_data.duplicate(true) as PickupData
	parent.add_child(pickup)
	pickup.global_position = actor.global_position
	loot_dropped.emit(pickup)
