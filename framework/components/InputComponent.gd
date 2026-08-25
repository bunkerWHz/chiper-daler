extends Component
class_name InputComponent

const INPUT_PROCESS_PRIORITY := -100
const MOVE_LEFT_ACTION: StringName = &"move_left"
const MOVE_RIGHT_ACTION: StringName = &"move_right"
const JUMP_ACTION: StringName = &"jump"
const INTERACT_ACTION: StringName = &"interact"
const ATTACK_ACTION: StringName = &"attack"
const GUARD_ACTION: StringName = &"guard"

var _move_axis: float = 0.0
var _jump_pressed: bool = false
var _jump_released: bool = false
var _interact_pressed: bool = false
var _attack_pressed: bool = false
var _guard_pressed: bool = false


func _ready() -> void:
	process_priority = INPUT_PROCESS_PRIORITY
	process_physics_priority = INPUT_PROCESS_PRIORITY


func get_move_axis() -> float:
	return _move_axis


func consume_jump_pressed() -> bool:
	if not _jump_pressed:
		return false

	_jump_pressed = false
	return true


func is_jump_released() -> bool:
	return _jump_released


func consume_interact_pressed() -> bool:
	if not _interact_pressed:
		return false

	_interact_pressed = false
	return true


func consume_attack_pressed() -> bool:
	if not _attack_pressed:
		return false

	_attack_pressed = false
	return true


func is_guard_pressed() -> bool:
	return _guard_pressed


func _process(_delta: float) -> void:
	_interact_pressed = Input.is_action_just_pressed(INTERACT_ACTION)
	_attack_pressed = Input.is_action_just_pressed(ATTACK_ACTION)
	_guard_pressed = Input.is_action_pressed(GUARD_ACTION)


func _physics_process(_delta: float) -> void:
	_move_axis = Input.get_axis(MOVE_LEFT_ACTION, MOVE_RIGHT_ACTION)
	_jump_released = Input.is_action_just_released(JUMP_ACTION)

	if Input.is_action_just_pressed(JUMP_ACTION):
		_jump_pressed = true
