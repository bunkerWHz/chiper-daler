extends Component
class_name ExperienceRewardComponent

## Legacy name preserves authored enemy scenes and reward amounts.
signal amber_dropped(pickup: AmberShardPickup)
const PICKUP_SCENE := preload("res://features/loot/AmberShardPickup.tscn")
@export var config: ExperienceRewardConfig
var _health: HealthComponent
var _was_awarded := false

func on_initialize() -> void:
	_health = actor.get_component(HealthComponent) as HealthComponent
	if config == null or config.amount <= 0 or _health == null or not _health.is_enabled:
		push_error("ExperienceRewardComponent requires a reward and enabled health")
		disable()
		return
	if not _health.died.is_connected(_on_health_died):
		_health.died.connect(_on_health_died)

func should_disable_on_actor_death() -> bool:
	return false

func _on_health_died() -> void:
	if _was_awarded:
		return
	_was_awarded = true
	var parent := actor.get_parent()
	if parent == null:
		return
	var pickup := PICKUP_SCENE.instantiate() as AmberShardPickup
	pickup.amount = config.amount
	if parent.is_inside_tree():
		_spawn.call_deferred(weakref(parent), pickup, actor.global_position, weakref(self))
	else:
		_spawn(weakref(parent), pickup, actor.global_position, weakref(self))

static func _spawn(parent_ref: WeakRef, pickup: AmberShardPickup, position: Vector2, source_ref: WeakRef) -> void:
	var parent := parent_ref.get_ref() as Node
	if not is_instance_valid(parent) or parent.is_queued_for_deletion():
		pickup.free()
		return
	parent.add_child(pickup)
	pickup.global_position = position
	var source := source_ref.get_ref() as ExperienceRewardComponent
	if is_instance_valid(source):
		source.amber_dropped.emit(pickup)
