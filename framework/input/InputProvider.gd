extends RefCounted
class_name InputProvider


func get_move_axis() -> float:
	return 0.0


func consume_jump_pressed() -> bool:
	return false


func is_jump_released() -> bool:
	return false


func consume_interact_pressed() -> bool:
	return false
