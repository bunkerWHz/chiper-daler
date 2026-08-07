extends Component
class_name InputComponent

var move_input: float = 0.0
var jump_requested: bool = false

func get_move_input() -> float:
	return move_input
	
func consume_jump_request() -> bool:
	if not jump_requested:
		return false

	jump_requested = false
	return true
	
func is_jump_released() -> bool:
	return Input.is_action_just_released("jump")
	
func _physics_process(_delta: float) -> void:
	move_input = Input.get_axis("move_left", "move_right")

	if Input.is_action_just_pressed("jump"):
		jump_requested = true
	
