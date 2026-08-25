extends Component
class_name EnemyPatrolComponent

@export var config: EnemyPatrolConfig

var _movement_component: EnemyMovementComponent
var _ground_sensor: EnemyGroundSensorComponent
var _chase_component: EnemyChaseComponent
var _attack_component: EnemyAttackComponent


func on_initialize() -> void:
	if config == null:
		push_error("EnemyPatrolComponent requires EnemyPatrolConfig")
		disable()
		return

	if not (config.turn_at_ledges or config.turn_at_walls):
		push_error("EnemyPatrolComponent has an invalid config")
		disable()
		return

	_movement_component = (
		actor.get_component(EnemyMovementComponent)
		as EnemyMovementComponent
	)
	_ground_sensor = (
		actor.get_component(EnemyGroundSensorComponent)
		as EnemyGroundSensorComponent
	)

	if _movement_component == null or not _movement_component.is_enabled:
		push_error("EnemyPatrolComponent requires EnemyMovementComponent")
		disable()
		return

	if _ground_sensor == null or not _ground_sensor.is_enabled:
		push_error("EnemyPatrolComponent requires EnemyGroundSensorComponent")
		disable()
		return

	_chase_component = (
		actor.get_component(EnemyChaseComponent)
		as EnemyChaseComponent
	)
	_attack_component = (
		actor.get_component(EnemyAttackComponent)
		as EnemyAttackComponent
	)

func _physics_process(_delta: float) -> void:
	if not _ground_sensor.is_grounded() or not _can_patrol():
		return

	var direction := _movement_component.get_move_direction()

	if is_zero_approx(direction):
		return

	var should_turn := (
		(config.turn_at_walls and _ground_sensor.has_wall(direction))
		or (
			config.turn_at_ledges
			and not _ground_sensor.has_floor_ahead(direction)
		)
	)

	if should_turn:
		reverse_direction()


func reverse_direction() -> bool:
	if not is_enabled or not _movement_component.is_enabled:
		return false

	var direction := _movement_component.get_move_direction()

	if is_zero_approx(direction):
		return false

	_movement_component.set_move_direction(-direction)
	return true


func _can_patrol() -> bool:
	if not _movement_component.is_enabled:
		return false

	if (
		_chase_component != null
		and _chase_component.is_enabled
		and _chase_component.is_chasing()
	):
		return false

	if (
		_attack_component != null
		and _attack_component.is_enabled
		and _attack_component.has_target()
	):
		return false

	return true
