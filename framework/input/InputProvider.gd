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


func consume_attack_pressed() -> bool:
	return false


func is_attack_pressed() -> bool:
	return false


func consume_attack_released() -> bool:
	return false


func is_guard_pressed() -> bool:
	return false


func consume_guard_just_pressed() -> bool:
	return false


func consume_equipment_slot_request() -> int:
	return -1
