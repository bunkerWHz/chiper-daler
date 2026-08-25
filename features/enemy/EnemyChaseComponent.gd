extends Component
class_name EnemyChaseComponent

const COMBAT_TARGETING := preload("res://features/combat/CombatTargeting.gd")

@export var config: EnemyChaseConfig

var _movement_component: EnemyMovementComponent
var _attack_component: EnemyAttackComponent
var _ground_sensor: EnemyGroundSensorComponent
var _detection_area: Area2D
var _targets: Array[HurtboxComponent] = []
var _stored_move_direction: float = 0.0
var _is_chasing: bool = false


func on_initialize() -> void:
	if config == null:
		push_error("EnemyChaseComponent requires EnemyChaseConfig")
		disable()
		return

	if config.horizontal_range <= 0.0 or config.vertical_range <= 0.0:
		push_error("EnemyChaseComponent has an invalid config")
		disable()
		return

	_movement_component = (
		actor.get_component(EnemyMovementComponent)
		as EnemyMovementComponent
	)

	if _movement_component == null or not _movement_component.is_enabled:
		push_error("EnemyChaseComponent requires EnemyMovementComponent")
		disable()
		return

	_attack_component = (
		actor.get_component(EnemyAttackComponent)
		as EnemyAttackComponent
	)

	if _attack_component != null and not _attack_component.is_enabled:
		_attack_component = null

	if config.avoid_unsafe_ground:
		_ground_sensor = (
			actor.get_component(EnemyGroundSensorComponent)
			as EnemyGroundSensorComponent
		)

		if _ground_sensor == null or not _ground_sensor.is_enabled:
			push_error("EnemyChaseComponent requires EnemyGroundSensorComponent")
			disable()


func _ready() -> void:
	_detection_area = get_node_or_null("DetectionArea2D") as Area2D

	if _detection_area == null:
		push_error("EnemyChaseComponent requires DetectionArea2D")
		disable()
		return

	var collision_shape := (
		_detection_area.get_node_or_null("CollisionShape2D")
		as CollisionShape2D
	)

	if collision_shape == null or not collision_shape.shape is RectangleShape2D:
		push_error("EnemyChaseComponent requires a RectangleShape2D")
		disable()
		return

	var rectangle := collision_shape.shape.duplicate() as RectangleShape2D
	rectangle.size = Vector2(
		config.horizontal_range * 2.0,
		config.vertical_range * 2.0
	)
	collision_shape.shape = rectangle

	if not _detection_area.area_entered.is_connected(_on_area_entered):
		_detection_area.area_entered.connect(_on_area_entered)

	if not _detection_area.area_exited.is_connected(_on_area_exited):
		_detection_area.area_exited.connect(_on_area_exited)


func _process(_delta: float) -> void:
	_remove_invalid_targets()

	if _targets.is_empty():
		_restore_patrol()
		return

	if not _movement_component.is_enabled:
		return

	if (
		_attack_component != null
		and _attack_component.is_enabled
		and _attack_component.has_target()
	):
		return

	var target := COMBAT_TARGETING.get_closest_hostile(actor, _targets)

	if target == null:
		_restore_patrol()
		return

	if not _is_chasing:
		_stored_move_direction = _movement_component.get_move_direction()
		_is_chasing = true

	var direction := signf(
		target.actor.global_position.x - actor.global_position.x
	)

	if is_zero_approx(direction):
		return

	if (
		_ground_sensor != null
		and not _ground_sensor.is_direction_safe(direction)
	):
		_movement_component.stop()
		return

	_movement_component.set_move_direction(direction)


func has_target() -> bool:
	return not _targets.is_empty()


func is_chasing() -> bool:
	return _is_chasing


func disable() -> void:
	_targets.clear()
	_restore_patrol()
	super.disable()


func _on_area_entered(other_area: Area2D) -> void:
	if not is_enabled:
		return

	var hurtbox := other_area.get_parent() as HurtboxComponent

	if (
		not COMBAT_TARGETING.is_valid_hostile(actor, hurtbox)
		or _targets.has(hurtbox)
	):
		return

	_targets.append(hurtbox)


func _on_area_exited(other_area: Area2D) -> void:
	var hurtbox := other_area.get_parent() as HurtboxComponent

	if hurtbox != null:
		_targets.erase(hurtbox)

	if _targets.is_empty():
		_restore_patrol()


func _remove_invalid_targets() -> void:
	for index in range(_targets.size() - 1, -1, -1):
		if not COMBAT_TARGETING.is_valid_hostile(actor, _targets[index]):
			_targets.remove_at(index)


func _restore_patrol() -> void:
	if not _is_chasing:
		return

	if not _movement_component.is_enabled:
		return

	_movement_component.set_move_direction(_stored_move_direction)
	_is_chasing = false
