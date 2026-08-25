extends Component
class_name EnemyPatrolComponent

@export var config: EnemyPatrolConfig

var _body_component: CharacterBodyComponent
var _movement_component: EnemyMovementComponent
var _chase_component: EnemyChaseComponent
var _attack_component: EnemyAttackComponent
var _floor_ray: RayCast2D
var _wall_ray: RayCast2D


func on_initialize() -> void:
	if config == null:
		push_error("EnemyPatrolComponent requires EnemyPatrolConfig")
		disable()
		return

	if (
		config.ledge_check_distance <= 0.0
		or config.floor_check_depth <= 0.0
		or config.wall_check_distance <= 0.0
	):
		push_error("EnemyPatrolComponent has an invalid config")
		disable()
		return

	_body_component = (
		actor.get_component(CharacterBodyComponent)
		as CharacterBodyComponent
	)
	_movement_component = (
		actor.get_component(EnemyMovementComponent)
		as EnemyMovementComponent
	)

	if _body_component == null or not _body_component.is_enabled:
		push_error("EnemyPatrolComponent requires CharacterBodyComponent")
		disable()
		return

	if _movement_component == null or not _movement_component.is_enabled:
		push_error("EnemyPatrolComponent requires EnemyMovementComponent")
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


func _ready() -> void:
	_floor_ray = get_node_or_null("FloorRayCast2D") as RayCast2D
	_wall_ray = get_node_or_null("WallRayCast2D") as RayCast2D

	if _floor_ray == null or _wall_ray == null:
		push_error("EnemyPatrolComponent requires floor and wall RayCast2D nodes")
		disable()
		return

	var body := _body_component.get_body()
	_floor_ray.add_exception(body)
	_wall_ray.add_exception(body)


func _physics_process(_delta: float) -> void:
	if not _body_component.is_on_floor() or not _can_patrol():
		return

	var direction := _movement_component.get_move_direction()

	if is_zero_approx(direction):
		return

	_update_rays(direction)

	if _wall_ray.is_colliding() or not _floor_ray.is_colliding():
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


func _update_rays(direction: float) -> void:
	var normalized_direction := signf(direction)
	_floor_ray.position.x = normalized_direction * config.ledge_check_distance
	_floor_ray.target_position = Vector2(0.0, config.floor_check_depth)
	_wall_ray.target_position = Vector2(
		normalized_direction * config.wall_check_distance,
		0.0
	)
	_floor_ray.force_raycast_update()
	_wall_ray.force_raycast_update()
