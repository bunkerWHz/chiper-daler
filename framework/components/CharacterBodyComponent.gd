extends Component
class_name CharacterBodyComponent

const BODY_NODE: String = "CharacterBody2D"

@export_flags_2d_physics var collision_layer: int = 1
@export_flags_2d_physics var collision_mask: int = 1

var _body: CharacterBody2D


func on_initialize() -> void:
	_body = get_node_or_null(BODY_NODE) as CharacterBody2D

	if _body == null:
		push_error("CharacterBodyComponent requires CharacterBody2D")
		disable()
		return

	_body.collision_layer = collision_layer
	_body.collision_mask = collision_mask


func get_velocity() -> Vector2:
	return _body.velocity


func get_body() -> CharacterBody2D:
	return _body


func set_velocity(value: Vector2) -> void:
	_body.velocity = value


func get_real_velocity() -> Vector2:
	return _body.get_real_velocity()


func is_on_floor() -> bool:
	return _body.is_on_floor()


func is_on_wall() -> bool:
	return _body.is_on_wall()


func is_on_ceiling() -> bool:
	return _body.is_on_ceiling()


func get_floor_normal() -> Vector2:
	return _body.get_floor_normal()


func get_wall_normal() -> Vector2:
	return _body.get_wall_normal()


func move_and_slide() -> void:
	_body.move_and_slide()
	_sync_actor_position()


func _sync_actor_position() -> void:
	actor.global_position = _body.global_position
	_body.position = Vector2.ZERO
