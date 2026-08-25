extends Component
class_name EnemyGroundSensorComponent

@export var config: EnemyGroundSensorConfig

var _body_component: CharacterBodyComponent
var _floor_ray: RayCast2D
var _wall_ray: RayCast2D


func on_initialize() -> void:
	if config == null:
		push_error("EnemyGroundSensorComponent requires EnemyGroundSensorConfig")
		disable()
		return

	if (
		config.ledge_check_distance <= 0.0
		or config.floor_check_depth <= 0.0
		or config.wall_check_distance <= 0.0
	):
		push_error("EnemyGroundSensorComponent has an invalid config")
		disable()
		return

	_body_component = (
		actor.get_component(CharacterBodyComponent)
		as CharacterBodyComponent
	)

	if _body_component == null or not _body_component.is_enabled:
		push_error("EnemyGroundSensorComponent requires CharacterBodyComponent")
		disable()


func _ready() -> void:
	_floor_ray = get_node_or_null("FloorRayCast2D") as RayCast2D
	_wall_ray = get_node_or_null("WallRayCast2D") as RayCast2D

	if _floor_ray == null or _wall_ray == null:
		push_error(
			"EnemyGroundSensorComponent requires floor and wall RayCast2D nodes"
		)
		disable()
		return

	var body := _body_component.get_body()
	_floor_ray.add_exception(body)
	_wall_ray.add_exception(body)


func is_grounded() -> bool:
	return is_enabled and _body_component.is_on_floor()


func has_wall(direction: float) -> bool:
	if not is_grounded() or is_zero_approx(direction):
		return false

	_update_wall_ray(direction)
	return _wall_ray.is_colliding()


func has_floor_ahead(direction: float) -> bool:
	if not is_grounded() or is_zero_approx(direction):
		return true

	_update_floor_ray(direction)
	return _floor_ray.is_colliding()


func is_direction_safe(direction: float) -> bool:
	return not has_wall(direction) and has_floor_ahead(direction)


func _update_floor_ray(direction: float) -> void:
	_floor_ray.position.x = signf(direction) * config.ledge_check_distance
	_floor_ray.target_position = Vector2(0.0, config.floor_check_depth)
	_floor_ray.force_raycast_update()


func _update_wall_ray(direction: float) -> void:
	_wall_ray.target_position = Vector2(
		signf(direction) * config.wall_check_distance,
		0.0
	)
	_wall_ray.force_raycast_update()
