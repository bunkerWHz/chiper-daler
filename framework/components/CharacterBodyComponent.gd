extends Component
class_name CharacterBodyComponent

const BODY_NODE := "CharacterBody2D"

var body: CharacterBody2D


func _ready() -> void:
	body = find_child(BODY_NODE) as CharacterBody2D

	if body == null:
		push_error("CharacterBodyComponent requires CharacterBody2D")
		disable()


func get_body() -> CharacterBody2D:
	if body == null:
		body = find_child(BODY_NODE) as CharacterBody2D

	return body


func is_on_floor() -> bool:
	return body.is_on_floor()


func move() -> void:
	body.move_and_slide()
	_sync_actor_position()


func _sync_actor_position() -> void:
	actor.global_position = body.global_position
	body.position = Vector2.ZERO
