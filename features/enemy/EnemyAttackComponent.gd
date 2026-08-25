extends Component
class_name EnemyAttackComponent

@export var config: EnemyAttackConfig

var _attack_component: AttackComponent
var _movement_component: EnemyMovementComponent
var _detection_area: Area2D
var _targets: Array[HurtboxComponent] = []
var _stored_move_direction: float = 0.0
var _movement_stopped: bool = false


func on_initialize() -> void:
	if config == null:
		push_error("EnemyAttackComponent requires EnemyAttackConfig")
		disable()
		return

	if config.attack_range <= 0.0:
		push_error("EnemyAttackConfig attack_range must be greater than zero")
		disable()
		return

	_attack_component = actor.get_component(AttackComponent) as AttackComponent

	if _attack_component == null or not _attack_component.is_enabled:
		push_error("EnemyAttackComponent requires an enabled AttackComponent")
		disable()
		return

	_movement_component = (
		actor.get_component(EnemyMovementComponent)
		as EnemyMovementComponent
	)


func _ready() -> void:
	_detection_area = get_node_or_null("DetectionArea2D") as Area2D

	if _detection_area == null:
		push_error("EnemyAttackComponent requires DetectionArea2D")
		disable()
		return

	var collision_shape := (
		_detection_area.get_node_or_null("CollisionShape2D")
		as CollisionShape2D
	)

	if collision_shape == null or not collision_shape.shape is RectangleShape2D:
		push_error("EnemyAttackComponent requires a RectangleShape2D")
		disable()
		return

	var rectangle := collision_shape.shape as RectangleShape2D
	rectangle.size = Vector2.ONE * config.attack_range * 2.0

	if not _detection_area.area_entered.is_connected(_on_area_entered):
		_detection_area.area_entered.connect(_on_area_entered)

	if not _detection_area.area_exited.is_connected(_on_area_exited):
		_detection_area.area_exited.connect(_on_area_exited)


func _process(_delta: float) -> void:
	_remove_invalid_targets()

	if _targets.is_empty():
		_resume_movement()
		return

	_stop_movement()
	_attack_component.attack()


func has_target() -> bool:
	return not _targets.is_empty()


func disable() -> void:
	_targets.clear()
	_resume_movement()
	super.disable()


func _on_area_entered(other_area: Area2D) -> void:
	if not is_enabled:
		return

	var hurtbox := other_area.get_parent() as HurtboxComponent

	if not _is_valid_target(hurtbox) or _targets.has(hurtbox):
		return

	_targets.append(hurtbox)


func _on_area_exited(other_area: Area2D) -> void:
	var hurtbox := other_area.get_parent() as HurtboxComponent

	if hurtbox != null:
		_targets.erase(hurtbox)

	if _targets.is_empty():
		_resume_movement()


func _remove_invalid_targets() -> void:
	for index in range(_targets.size() - 1, -1, -1):
		if not _is_valid_target(_targets[index]):
			_targets.remove_at(index)


func _is_valid_target(hurtbox: HurtboxComponent) -> bool:
	if (
		hurtbox == null
		or not is_instance_valid(hurtbox)
		or not hurtbox.is_enabled
		or hurtbox.actor == actor
		or not is_instance_valid(hurtbox.actor)
	):
		return false

	var health := hurtbox.actor.get_component(HealthComponent) as HealthComponent

	if health == null or not health.is_enabled or not health.is_alive():
		return false

	var source_faction := (
		actor.get_component(CombatFactionComponent)
		as CombatFactionComponent
	)
	var target_faction := (
		hurtbox.actor.get_component(CombatFactionComponent)
		as CombatFactionComponent
	)

	if source_faction == null or target_faction == null:
		return true

	return source_faction.is_hostile_to(target_faction.faction)


func _stop_movement() -> void:
	if (
		_movement_stopped
		or not config.stop_movement_in_range
		or _movement_component == null
		or not _movement_component.is_enabled
	):
		return

	_stored_move_direction = _movement_component.get_move_direction()
	_movement_component.stop()
	_movement_stopped = true


func _resume_movement() -> void:
	if not _movement_stopped:
		return

	if _movement_component == null or not is_instance_valid(_movement_component):
		_movement_stopped = false
		return

	if not _movement_component.is_enabled:
		return

	_movement_component.set_move_direction(_stored_move_direction)
	_movement_stopped = false
