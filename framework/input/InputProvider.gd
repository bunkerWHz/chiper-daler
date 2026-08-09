extends RefCounted
class_name InputProvider

func get_move_input() -> float:
	return 0.0

func consume_jump_request() -> bool:
	return false

func is_jump_released() -> bool:
	return false
